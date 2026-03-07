import { useMemo, useState } from "react";
import { askAssistant } from "../api/campusApi";
import { assistantReply } from "../services/campusEngine";

const quickPrompts = [
  "Where am I on campus?",
  "Nearest food court",
  "Nearest library",
  "Tell me about Administrative Block",
];

function AssistantWidget({ userPosition, locations, userOnCampus, fallbackMode = false }) {
  const initialMessages = useMemo(
    () => [
      {
        role: "assistant",
        content:
          "Ask about nearby places, your campus area, route ideas, or any mapped Parul University building.",
      },
    ],
    [],
  );
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState(initialMessages);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);

  async function sendPrompt(prompt) {
    const trimmed = String(prompt || "").trim();

    if (!trimmed || loading) {
      return;
    }

    const userMessage = { role: "user", content: trimmed };
    setMessages((prev) => [...prev, userMessage]);
    setDraft("");
    setLoading(true);

    try {
      const response = fallbackMode
        ? assistantReply({
            locations,
            message: trimmed,
            userPosition,
            userOnCampus,
          })
        : await askAssistant(trimmed, userPosition);

      if (!response?.reply) {
        throw new Error("Missing assistant reply");
      }

      setMessages((prev) => [...prev, { role: "assistant", content: response.reply }]);
    } catch {
      const fallback = assistantReply({
        locations,
        message: trimmed,
        userPosition,
        userOnCampus,
      });

      setMessages((prev) => [...prev, { role: "assistant", content: fallback.reply }]);
    } finally {
      setLoading(false);
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();
    await sendPrompt(draft);
  }

  return (
    <div className="assistant-widget">
      {open ? (
        <section className="assistant-panel">
          <header className="assistant-header">
            <div>
              <h3>Campus Assistant</h3>
              <p>{fallbackMode ? "Using local Parul campus knowledge" : "Live assistant with local fallback"}</p>
            </div>
            <button type="button" onClick={() => setOpen(false)}>
              Close
            </button>
          </header>

          <div className="assistant-quick-prompts">
            {quickPrompts.map((prompt) => (
              <button key={prompt} type="button" onClick={() => sendPrompt(prompt)}>
                {prompt}
              </button>
            ))}
          </div>

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

          <form onSubmit={handleSubmit} className="assistant-form">
            <input
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              placeholder="Ask about a building, route, hostel, library, or food court"
            />
            <button type="submit" disabled={loading}>
              Send
            </button>
          </form>
        </section>
      ) : null}

      <button
        type="button"
        className="assistant-fab"
        onClick={() => setOpen((value) => !value)}
      >
        {open ? "Hide Assistant" : "Ask Campus Assistant"}
      </button>
    </div>
  );
}

export default AssistantWidget;
