import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

interface Message {
  id: int;
  user_id: string;
  message: string;
}

interface WebHookPayload {
  type: "INSERT";
  table: string;
  record: Message;
  schema: "public";
  old_record: null | Message;
}

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  const paylod: WebHookPayload = await req.json();
  const { data } = await supabase.from("profiles").select("fcm_token").eq("id", paylod.record.user_id).single();

  const fcm_token = data.fcm_token as string;

  const { default: serviceAccount } = await import("../service-account.json", {
    with: { type: "json" },
  });

  const accesToken = await getAccesToken({
    clientEmail: serviceAccount.client_email,
    privateKey: serviceAccount.private_key,
  });

  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accesToken}`,
    },
    body: JSON.stringify({
      message: {
        token: fcm_token,
        notification: {
          title: "New message",
          body: paylod.record.message,
        },
      },
    }),
  });

  const resData = await res.json();
  if (res.status < 200 || 299 < res.status) {
    throw resData;
  }

  return new Response(JSON.stringify(resData), { headers: { "Content-Type": "application/json" } });
});

const getAccesToken = async ({
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
    jwtClient.authorize((err, tokens) => {
      if (err) {
        reject(err);
      }
      resolve(tokens.access_token);
    });
  });
};
