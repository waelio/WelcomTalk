const WS_URL = "wss://waelio-messaging.onrender.com";

async function main() {
  const logs = [];
  const clients = [];

  function makeClient(name) {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(WS_URL);
      const client = { name, ws, id: null, messages: [] };
      clients.push(client);

      const timeout = setTimeout(
        () => reject(new Error(name + " timeout connecting")),
        45000,
      );

      ws.onopen = () => logs.push("[" + name + "] open");
      ws.onmessage = (event) => {
        const text = String(event.data);
        logs.push("[" + name + "] <- " + text);
        let msg;
        try {
          msg = JSON.parse(text);
        } catch {
          return;
        }
        if (msg.type === "register-success") {
          client.id = msg.id;
          clearTimeout(timeout);
          resolve(client);
          return;
        }
        client.messages.push(msg);
      };
      ws.onerror = () => {
        clearTimeout(timeout);
        reject(new Error(name + " websocket error"));
      };
      ws.onclose = () => logs.push("[" + name + "] closed");
    });
  }

  try {
    const a = await makeClient("A");
    const b = await makeClient("B");

    await new Promise((r) => setTimeout(r, 1000));

    const payload = JSON.stringify({
      type: "join-session",
      sessionCode: "TEST42",
      userId: "guest-user",
      userName: "Guest",
      isHost: false,
      session: null,
      requestType: null,
    });

    a.ws.send(JSON.stringify({ type: "broadcast", payload }));
    logs.push("[A] -> broadcast join-session");

    await new Promise((r) => setTimeout(r, 3000));

    console.log("--- LOGS ---");
    console.log(logs.join("\n"));
    console.log("--- SUMMARY ---");
    console.log(
      JSON.stringify(
        {
          aId: a.id,
          bId: b.id,
          aMessages: a.messages,
          bMessages: b.messages,
        },
        null,
        2,
      ),
    );
  } finally {
    for (const c of clients) {
      try {
        c.ws.close();
      } catch {}
    }
    setTimeout(() => process.exit(0), 500);
  }
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
});
