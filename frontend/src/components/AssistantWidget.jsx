import { useState } from "react";
import { askAssistant } from "../api/campusApi";

const initialMessages = [
  {
    role: "assistant",
    content:
      "Ask about nearby places, your location, or any campus building details.",
  },
];

function AssistantWidget({ userPosition }) {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState(initialMessages);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);

  async function sendMessage(event) {
    event.preventDefault();
    const trimmed = draft.trim();

    if (!trimmed || loading) {
      return;
    }

    const userMessage = { role: "user", content: trimmed };
    setMessages((prev) => [...prev, userMessage]);
    setDraft("");
    setLoading(true);

    try {
      const response = await askAssistant(trimmed, userPosition);
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: response.reply || "No response generated." },
      ]);
    } catch {
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: "Assistant is not available right now. Try again shortly.",
        },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="assistant-widget">
      {open ? (
        <section className="assistant-panel">
          <header className="assistant-header">
            <h3>AI Assistant</h3>
            <button type="button" onClick={() => setOpen(false)}>
              Close
            </button>
          </header>

          <div className="assistant-messages">
            {messages.map((message, index) => (
              <div
                key={`${message.role}-${index}`}
                className={message.role === "user" ? "bubble user" : "bubble assistant"}
              >
                {message.content}
              </div>
            ))}
            {loading ? <div className="bubble assistant">Thinking...</div> : null}
          </div>

          <form onSubmit={sendMessage} className="assistant-form">
            <input
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              placeholder="Type your question..."
            />
            <button type="submit" disabled={loading}>
              Send
            </button>
          </form>
        </section>
      ) : null}

      <button type="button" className="assistant-fab" onClick={() => setOpen((value) => !value)}>
        {open ? "Hide Assistant" : "Open Assistant"}
      </button>
    </div>
  );
}

export default AssistantWidget;
