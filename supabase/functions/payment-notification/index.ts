import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

type Payment = {
  id: number;
  unitTenancyId: number;
  amount: number;
  paymentDate: string;
  dueDate: string;
  paymentStatus: string;
  paymentMethod: string;
  referenceNumber: string;
  description: string;
  createdAt: string;
  updatedAt: string;
  organizationId: string;
  propertyId: number;
  isBundlePayment: boolean;
  discountGroupId: number;
};

type WebhookPayload = {
  type: "INSERT";
  table: string;
  schema: "public";
  record: Payment;
  oldRecord: Payment | null;
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  // get fcm tokens from profiles table
  const payload: WebhookPayload = await req.json();
  const { data }: {
    data: [{ fcm_token: string }];
  } = await supabase.from(
    "profiles",
  ).select("fcm_token").eq(
    "organization_id",
    payload.record.organizationId,
  );
  const fcmTokens = data.map((profile) => profile.fcm_token);

  // send notification to fcm tokens
  if (fcmTokens.length === 0) {
    return new Response(
      JSON.stringify({ message: "No fcm tokens found" }),
      { status: 404 },
    );
  }

  const { default: serviceAccount } = await import("../service-account.json", {
    with: { type: "json" },
  });

  const accessToken = await getAccessToken({clientEmail: serviceAccount.client_email, privateKey: serviceAccount.private_key});

  const responses = [];
  for (const fcmToken of fcmTokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: "New Payment Notification",
              body:
                `A new payment of ${payload.record.amount} has been made: ${payload.record.description}`,
            },
          },
        }),
      },
    );
    const resData = await res.json();
    if (res.status < 200 || 299 < res.status) {
      throw resData;
    }
    responses.push(resData);
  }

  return new Response(
    JSON.stringify(responses),
    { headers: { "Content-Type": "application/json" } },
  );
});

const getAccessToken = ({
  clientEmail,
  privateKey,
}: {
  clientEmail: string;
  privateKey: string;
}): Promise<string> => {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    jwtClient.authorize((err: any, tokens: any) => {
      if (err) {
        reject(err);
        return;
      } else {
        resolve(tokens.access_token);
      }
    });
  });
};
