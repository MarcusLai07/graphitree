import { Findings, Page, Section, Variant } from "@/playground/kit"
import { AgentChat } from "@/demos/ai/agent-chat"
import { ApprovalCard } from "@/demos/ai/approval-card"
import { LoadingState } from "@/demos/ai/loading-state"
import { AIElementsChainOfThought, AIElementsSources, Replayable, StreamTextDemo, TaskTimeline } from "@/demos/ai/showcase"
import { StreamingAnswer } from "@/demos/ai/streaming"
import { Thinking } from "@/demos/ai/thinking"
import { ToolChips } from "@/demos/ai/tool-chips"

const BUI = "Beautiful UI"
const AIE = "AI Elements"

export default function AIPage() {
  return (
    <Page
      title="AI interface"
      intro={
        <>
          Beautiful UI is a free, MIT-licensed set of building blocks for agent interfaces: thinking traces, streamed answers
          with sources, approval cards, tool chips and task rows. There is no npm package. Each block is one self-contained
          .tsx file plus a shared foundation.css, served as a shadcn registry item. We copied six blocks by hand into{" "}
          <code className="text-xs">src/demos/ai/</code> and remapped their colours to our shadcn tokens. Vercel AI Elements
          is next to it as a candidate.
        </>
      }
      libs={[
        { name: "Beautiful UI", status: "playbook", url: "https://beautifului.dev", install: "copy from beautifului.dev/r/<name>.json" },
        { name: "Vercel AI Elements", status: "candidate", url: "https://ai-sdk.dev/elements", install: "npx shadcn add https://registry.ai-sdk.dev/<name>.json" },
      ]}
    >
      <Section
        title="A fake agent run, using all the blocks"
        description="Simulated with timers, with no model behind it. It loads, thinks, calls tools, stops to ask before opening pull requests, runs the tasks, then streams an answer with inline sources. Pick an option in the approval card, or deny it, and the rest of the run changes to match. Follow-ups and the composer start a short second turn."
        className="md:grid-cols-[3fr_2fr]"
      >
        <Variant label="Needs approval" lib={BUI} stageClassName="p-3" hint="Single-choice answers submit themselves after 480 ms. That's the original behaviour, and it's quick for a yes/no permission prompt.">
          <AgentChat />
        </Variant>
        <Variant label="Side panel, auto-approve on" lib={BUI} stageClassName="p-3" hint="Same blocks at panel width, like odyssey's side panel. The approval card is replaced by a one-line note.">
          <AgentChat compact autoApprove speed={1.2} />
        </Variant>
      </Section>

      <Section title="Progress: loading and thinking" description="For when the agent is busy. The label shimmers, and the trace opens while it works and folds into a one-line summary when it's done.">
        <Variant label="Loading state: Drive, Dots, Orbit" lib={BUI} stageClassName="flex-col items-start gap-4" hint="A 3×3 pixel grid with a live timer. We left out the original's fourth variant ('Surfer'): by default it plays a meme video hosted on the author's Vercel Blob.">
          <LoadingState label="Churning" pattern="Drive" />
          <LoadingState label="Indexing 30 repos" pattern="Dots" />
          <LoadingState label="Waiting for the model" pattern="Orbit" showElapsed={false} />
        </Variant>
        <Variant label="Thinking: steps" lib={BUI} stageClassName="items-start justify-start">
          <Replayable>{(k) => <Thinking key={k} variant="Steps" />}</Replayable>
        </Variant>
        <Variant label="Thinking: web search" lib={BUI} stageClassName="items-start justify-start" hint="The rows are real links.">
          <Replayable>{(k) => <Thinking key={k} variant="Search" />}</Replayable>
        </Variant>
        <Variant label="Thinking: coding and reasoning" lib={BUI} stageClassName="items-start justify-start gap-6">
          <Replayable>
            {(k) => (
              <div className="flex w-full flex-col gap-4">
                <Thinking key={`c${k}`} variant="Coding" />
                <Thinking key={`r${k}`} variant="Reasoning" />
              </div>
            )}
          </Replayable>
        </Variant>
      </Section>

      <Section title="Answers and sources" description="Words come out of a blur, and source chips appear inline next to the claims they back up. Copy, regenerate, rating and the sources list fade in once the stream ends.">
        <Variant label="Streamed answer, sources open" lib={BUI} stageClassName="items-start justify-start">
          <Replayable>{(k) => <StreamingAnswer key={k} defaultSourcesOpen />}</Replayable>
        </Variant>
        <Variant label="StreamText (character stream)" lib={BUI} stageClassName="items-start" hint="A smaller primitive: about 220 characters a second, with the last 6 blurred and a caret that blinks once the text settles. Type your own text and press Stream.">
          <StreamTextDemo />
        </Variant>
      </Section>

      <Section title="Approvals, tool calls and tasks" description="Human-in-the-loop questions, tool calls shown as compact chips with diffs, and live task status.">
        <Variant label="Approval card: three questions" lib={BUI} hint="One question at a time. The card's height animates, the counter rolls like an odometer, and you can type a custom answer. Checkbox questions wait for Continue.">
          <ApprovalCard />
        </Variant>
        <Variant label="Tool chips" lib={BUI} stageClassName="items-start" hint="Click a row to see what the tool did. Hover or focus a file chip to see its diff in a portal.">
          <Replayable>{(k) => <ToolChips key={k} />}</Replayable>
        </Variant>
        <Variant label="Task rows: capsules" lib={BUI} stageClassName="items-start" hint="The original's timeline: a row opens while it runs, and the third task fails once, then completes.">
          <Replayable>{(k) => <TaskTimeline key={k} variant="Capsules" />}</Replayable>
        </Variant>
        <Variant label="Task rows: list" lib={BUI} stageClassName="items-start">
          <Replayable>{(k) => <TaskTimeline key={k} variant="List" />}</Replayable>
        </Variant>
      </Section>

      <Section
        title="Candidate: Vercel AI Elements"
        description={
          <>
            We installed two items with the shadcn CLI: <code className="text-xs">chain-of-thought</code> and{" "}
            <code className="text-xs">sources</code>. They added <code className="text-xs">@radix-ui/react-use-controllable-state</code>{" "}
            and a Base UI <code className="text-xs">collapsible.tsx</code>, and skipped the existing badge. We didn't install{" "}
            <code className="text-xs">confirmation</code> (their approval block) or <code className="text-xs">tool</code>: both
            pull in the <code className="text-xs">ai</code> SDK (about 9 MB unpacked, plus zod as a peer dependency) just for
            types.
          </>
        }
      >
        <Variant label="Chain of thought" lib={AIE} stageClassName="items-start" hint="Compose it from parts and control it yourself. It doesn't animate here: its classes target Radix's data-[state=open], and Base UI sets data-open.">
          <AIElementsChainOfThought />
        </Variant>
        <Variant label="Sources" lib={AIE} stageClassName="items-start" hint="A plain collapsible list. Compare it with Beautiful UI's inline chips and avatar stack above.">
          <AIElementsSources />
        </Variant>
      </Section>

      <Findings
        title="What we found: Beautiful UI"
        notes={[
          {
            tone: "good",
            text: "MIT licensed (© 2026 Shane Levine). The only dependency is React. Every block is one file you own, and the motion is plain CSS transitions and keyframes, without motion/framer-motion.",
          },
          {
            tone: "good",
            text: "Easy to copy: beautifului.dev/r/<name>.json is a standard shadcn registry item, so you can read it with curl before taking anything. Adapting a block is mostly find-and-replace on colour tokens.",
          },
          {
            tone: "bad",
            text: "Its foundation.css clashes with shadcn. It redefines --accent as a blue brand colour (shadcn uses --accent for hover backgrounds) and --font-sans. It adds a global :focus-visible outline, a striped body background and a global reduced-motion rule. It also imports an undeclared shadow-plugin package and has a stray closing brace. Don't paste it. Copy the keyframes and map the tokens: ink → foreground, ink-2/3 → muted-foreground, line → border, surface → card.",
          },
          {
            tone: "bad",
            text: "The blocks are written as gallery demos. Thinking, Tool Chips, Task Rows and Streaming Text play a hard-coded timeline with the demo data baked in. We had to add controlled props (working/visible, shown, revealed, per-row status) before they could follow a real agent. Plan for that on every block you take.",
          },
          {
            tone: "bad",
            text: "Accessibility needs a pass. ink-3 text is about 2.6:1 on white, so we used muted-foreground. Focus rings come only from the global foundation outline, so we added focus-visible rings. All four answer actions were labelled aria-label=\"Action\", and a role=\"status\" wrapped a timer that updates 10 times a second. Collapsed panels stayed tabbable, so we made them inert. Approval options are aria-pressed buttons, not a radio group.",
          },
          {
            tone: "good",
            text: "Dark mode works once the tokens are mapped. The originals ship their own .dark palette, which we didn't need. Reduced motion is respected, scoped to [data-bui]. When to use it: chat or agent panels in odyssey and admin portals. Copy only the blocks you need.",
          },
        ]}
      />

      <Findings
        title="What we found: Vercel AI Elements (candidate)"
        notes={[
          {
            tone: "good",
            text: "A real shadcn registry, built to compose with the AI SDK's message parts (useChat, ToolUIPart). It's the better pick if odyssey moves to the AI SDK, because the blocks are made to take its state directly.",
          },
          {
            tone: "bad",
            text: "It's written for Radix-flavoured shadcn. On our base-nova style, the CLI installs a Base UI collapsible, so the open/close animations (data-[state=…]) never fire. Chain of Thought also wraps its header and content in two separate Collapsible roots, so the trigger's aria-controls doesn't point at the panel.",
          },
          {
            tone: "bad",
            text: "Heavier and more fragile. confirmation and tool depend on the ai package for types. confirmation uses @ts-expect-error for 'AI SDK v6' states, and the current ai is 7.x, so tsc will probably flag those directives as unused. reasoning pulls in streamdown.",
          },
          {
            tone: "note",
            text: "It's plainer to look at than Beautiful UI: a list in a collapsible, versus inline chips, a shimmer and an animated trace. Keep it as a candidate for logic-heavy chat work, and use Beautiful UI for the look.",
          },
        ]}
      />
    </Page>
  )
}
