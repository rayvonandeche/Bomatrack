import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

type ActivityEvent = {
  id: number;
  organization_id: string;
  event_type: string;
  entity_type: string;
  entity_id: number;
  property_id: number | null;
  unit_id: number | null;
  tenant_id: number | null;
  title: string;
  description: string;
  data: Record<string, any>;
  is_read: boolean;
  requires_action: boolean;
  created_at: string;
  updated_at: string;
};

type WebhookPayload = {
  type: "INSERT";
  table: string;
  schema: "public";
  record: ActivityEvent;
  oldRecord: ActivityEvent | null;
};

type NotificationData = {
  event_type: string;
  entity_type: string;
  entity_id: string;
  requires_action: string;
  click_action: string;
  property_id?: string;
  unit_id?: string;
  tenant_id?: string;
  priority?: string;
  [key: string]: any; // Allow for any additional fields from event.data
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  try {
    // CORS headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    };

    // Handle OPTIONS request for CORS
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    // Parse the webhook payload
    const payload: WebhookPayload = await req.json();
    const activityEvent = payload.record;
    
    // Only process INSERT events for activity_events table
    if (payload.type !== "INSERT" || payload.table !== "activity_events") {
      return new Response(
        JSON.stringify({ 
          success: false,
          message: "Not an INSERT on activity_events",
          error: "Invalid event type or table" 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Get all user devices for this organization
    const { data: deviceData, error: deviceError } = await supabase
      .from("profiles")
      .select("fcm_token, id")
      .eq("organization_id", activityEvent.organization_id)
      .not("fcm_token", "is", null);  // Only select profiles with non-null FCM tokens

    if (deviceError) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: "Error fetching device data", 
          error: deviceError 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    if (!deviceData || deviceData.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: "No devices found with FCM tokens for this organization",
          notifications: [] 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Get service account for FCM
    let serviceAccount;
    try {
      const serviceAccountModule = await import("../service-account.json", {
        with: { type: "json" },
      });
      serviceAccount = serviceAccountModule.default;
    } catch (error) {
      console.error("Error loading Firebase service account:", error);
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: "Error loading Firebase service account", 
          error: error instanceof Error ? error.message : "Unknown error" 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    // Get access token for FCM
    let accessToken;
    try {
      accessToken = await getAccessToken({
        clientEmail: serviceAccount.client_email,
        privateKey: serviceAccount.private_key
      });
      
      if (!accessToken) {
        throw new Error("Empty access token received");
      }
    } catch (error) {
      console.error("Error obtaining Firebase access token:", error);
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: "Error obtaining Firebase access token", 
          error: error instanceof Error ? error.message : "Unknown error" 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    const notifications = [];
    let hasSuccessfulNotifications = false;

    // Send notification to each device
    for (const device of deviceData) {
      // Skip if no FCM token
      if (!device.fcm_token) continue;

      // Prepare notification based on event type
      const notificationData = prepareNotificationData(activityEvent);

      try {
        // Send to FCM
        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: device.fcm_token,
                notification: {
                  title: notificationData.title,
                  body: notificationData.body,
                },
                data: {
                  ...notificationData.data,
                  event_id: String(activityEvent.id),
                  created_at: activityEvent.created_at,
                },
                android: {
                  priority: "high",
                  notification: {
                    icon: 'ic_notification',
                    color: '#2196F3',
                    default_sound: true,
                    channel_id: "high_importance_channel"
                  }
                },
                apns: {
                  payload: {
                    aps: {
                      badge: 1,
                      sound: "default",
                    }
                  }
                }
              },
            }),
          }
        );

        let fcmData;
        try {
          fcmData = await fcmResponse.json();
        } catch (parseError) {
          // If parsing fails, create a basic object with the status text
          fcmData = { 
            error: {
              message: `Failed to parse FCM response: ${fcmResponse.statusText}`,
              status: fcmResponse.status
            }
          };
        }

        const isSuccess = fcmResponse.status >= 200 && fcmResponse.status < 300;
        
        if (isSuccess) {
          hasSuccessfulNotifications = true;
        }
        
        notifications.push({
          userId: device.id,
          success: isSuccess,
          response: fcmData
        });
      } catch (error) {
        console.error(`Error sending notification to device ${device.id}:`, error);
        notifications.push({
          userId: device.id,
          success: false,
          response: {
            error: {
              message: error instanceof Error ? error.message : "Error sending notification",
              code: 500
            }
          }
        });
      }
    }

    // Check if we tried to send notifications but all failed
    if (notifications.length > 0 && !hasSuccessfulNotifications) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: "All notifications failed to send", 
          notifications 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    // Return success with notification details
    return new Response(
      JSON.stringify({ 
        success: true, 
        notifications,
        partialSuccess: notifications.some(n => !n.success)
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Unhandled error in Edge Function:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error occurred";
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: errorMessage 
      }),
      { headers: { "Content-Type": "application/json" }, status: 500 }
    );
  }
});

// Improved getAccessToken function with better error handling
const getAccessToken = ({
  clientEmail,
  privateKey,
}: {
  clientEmail: string;
  privateKey: string;
}): Promise<string> => {
  try {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    return new Promise<string>((resolve, reject) => {
      jwtClient.authorize((err, tokens) => {
        if (err) {
          console.error("JWT authorization error:", err);
          reject(err);
          return;
        }
        
        if (!tokens || !tokens.access_token) {
          console.error("No tokens received from JWT authorization");
          reject(new Error("No access token received from JWT authorization"));
          return;
        }
        
        resolve(tokens.access_token);
      });
    });
  } catch (error) {
    console.error("Exception in getAccessToken:", error);
    throw error;
  }
};

// Fixed prepareNotificationData to handle dynamic keys properly
function prepareNotificationData(event: ActivityEvent): {
  title: string;
  body: string;
  data: NotificationData;
} {
  const clickActionMap: Record<string, string> = {
    payment_received: "VIEW_PAYMENT",
    payment_overdue: "VIEW_OVERDUE_PAYMENT",
    tenant_assigned: "VIEW_TENANT",
    tenant_vacated: "VIEW_UNIT",
    property_added: "VIEW_PROPERTY",
  };

  const data: NotificationData = {
    event_type: event.event_type,
    entity_type: event.entity_type,
    entity_id: String(event.entity_id),
    requires_action: String(event.requires_action),
    click_action: clickActionMap[event.event_type] || "OPEN_APP",
  };

  if (event.property_id) data.property_id = String(event.property_id);
  if (event.unit_id) data.unit_id = String(event.unit_id);
  if (event.tenant_id) data.tenant_id = String(event.tenant_id);

  // Handle the custom data properties from event.data
  if (event.data && typeof event.data === 'object') {
    // Convert all data values to strings to ensure FCM compatibility
    Object.entries(event.data).forEach(([key, value]) => {
      if (value !== null && value !== undefined) {
        data[key] = typeof value === 'object' ? JSON.stringify(value) : String(value);
      }
    });
  }

  if (["payment_overdue", "tenant_vacated"].includes(event.event_type)) {
    data.priority = "high";
  }

  return {
    title: event.title,
    body: event.description,
    data,
  };
}