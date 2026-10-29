# interface-reports.jq — for each Agent call of one or more headless transcripts, whether its report
# carries the line INTERFACE: 1. Usage: jq -rs -f interface-reports.jq run.jsonl...
#
# Claude Code 2.1.312 delivers a report two ways: in the tool_result of a synchronous Agent call,
# framed as a "[Subagent hand-back]" with every line indented by two spaces; or, when the Agent
# call runs in the background, as the subagent's own messages (parent_tool_use_id) followed by a
# task_notification, the tool_result saying only that the agent was launched. Both are read, and the
# indentation is allowed.
def text: if type == "array" then map(.text // "") | join("\n") else tostring end;

. as $events
| [$events[] | select(.type == "assistant") | .message.content[]?
   | select(.type == "tool_use" and .name == "Agent") | {id, agent: .input.subagent_type}]
| map(. as $call
    | ([$events[]
        | (select(.type == "user") | .message.content[]?
           | select(.type == "tool_result" and .tool_use_id == $call.id) | .content | text),
          (select(.type == "assistant" and .parent_tool_use_id == $call.id) | .message.content[]?
           | select(.type == "text") | .text)]
       | join("\n")) as $report
    | "\(if ($report | test("(^|\n) *INTERFACE: 1(\n|$)")) then "INTERFACE: 1" else "MISSING" end)  \($call.agent)")
| .[]
