import { Findings, Page, Section, Variant } from "@/playground/kit"
import { CliTranscript, PicksTable } from "@/demos/community/twenty-first"
import { AdminDashboard, LiquidToolbar, PhoneWithNav, SettingsHeader, ShadcnToolbar, TwoTabBars } from "@/demos/community/spots"

const T21 = "21st.dev"
const BLOCKS = "blocks.so (via 21st.dev)"
const RARE = "RareUI"

export default function CommunityPage() {
  return (
    <Page
      title="21st.dev & RareUI"
      intro={
        <>
          Two places to copy community components from. 21st.dev is a large registry (about 12,000 components, many authors)
          that installs through the shadcn CLI. RareUI, since renamed ShitUI, is one person's small MIT library of
          animated components. Its install is its own CLI, which we didn't run: we read the code on GitHub and copied it into{" "}
          <code className="text-xs">src/demos/community/</code>.
        </>
      }
      libs={[
        { name: "21st.dev", status: "playbook", url: "https://21st.dev", install: 'npx shadcn add "https://21st.dev/r/<author>/<name>"' },
        { name: "RareUI", status: "playbook", url: "https://rareui.in", install: "copy from github.com/Codewithswappy/ShitUI" },
      ]}
    >
      <Section
        title="21st.dev: the install needs an account now"
        className="md:grid-cols-1"
        description="We picked four popular components of different kinds (a hero, pricing, an animated button and stat cards) and ran the command each page shows. Every registry URL returned 403 'Authentication required', even 21st.dev's copy of shadcn's own button. Each page shows a usage snippet and a dependency list. It says the component's own source comes with a free account, which gives two copies a day. We didn't sign up."
      >
        <Variant label="What the CLI returns" lib={T21} stageClassName="p-4">
          <CliTranscript />
        </Variant>
        <Variant label="The four picks, from what the pages show without an account" lib={T21} stageClassName="p-4 items-start">
          <PicksTable />
        </Variant>
      </Section>

      <Section
        title="21st.dev pick from its upstream: stats cards"
        className="md:grid-cols-1"
        description={
          <>
            “Stats cards with links” is listed on 21st.dev with blocks.so as its source. blocks.so is MIT and runs an open
            shadcn registry, so <code className="text-xs">npx shadcn add https://blocks.so/r/stats-05.json</code> worked with
            no login. It added one file, <code className="text-xs">src/components/stats-05.tsx</code>, with no new
            dependencies, and skipped our existing card.
          </>
        }
      >
        <Variant label="In an admin dashboard" lib={BLOCKS} stageClassName="p-3" hint="Plain shadcn Card, so it picks up our tokens and dark mode with no work.">
          <AdminDashboard />
        </Variant>
        <Variant
          label="Squeezed into a narrow column"
          lib={BLOCKS}
          stageClassName="p-3"
          hint="It uses viewport breakpoints (sm:/lg:), not container queries. In a narrow panel on a wide screen it still tries 3 columns. The data is hard-coded in the file, there are no props, and the <dl> has <dd>s with no <dt>."
        >
          <AdminDashboard narrow />
        </Variant>
      </Section>

      <Section title="RareUI: animated tabs" description="A glass pill with a spring that slides the active background between tabs. It's 98 lines, uses motion/react and cn, and nothing else.">
        <Variant label="Settings page header (as copied)" lib={RARE} hint="Looks great once it's wrapped in <LayoutGroup id> (see the bug below). Try Tab: you'll land on the buttons, but you can't see which one has focus (outline-none, no ring), and there's no tablist or aria-selected.">
          <SettingsHeader />
        </Variant>
        <Variant label="Settings page header (our patch)" lib={RARE} hint="Same look, plus role=tablist/tab, aria-selected, arrow keys and a visible focus ring. About 20 changed lines.">
          <SettingsHeader patched />
        </Variant>
        <Variant label="Two bars on one page (as copied)" lib={RARE} hint="Bug: every copy uses layoutId='active-pill', so motion renders only one pill on the whole page. The other bar loses its pill and its white label disappears. Click either bar and watch the pill jump between them. Upstream fix: wrap each instance in <LayoutGroup id>, or scope the id as our patch does.">
          <TwoTabBars />
        </Variant>
        <Variant label="Two bars on one page (our patch)" lib={RARE} hint="Each instance scopes its layoutId with useId, so the pills stay in their own bars.">
          <TwoTabBars patched />
        </Variant>
      </Section>

      <Section title="RareUI: liquid tooltip and floating navigation" description="Spring physics on hover: the tooltip leans toward where the cursor moves across the trigger, and each nav icon has its own little animation.">
        <Variant label="Liquid tooltip on an editor toolbar" lib={RARE} stageClassName="flex-col gap-8" hint="Hover only. It doesn't open on keyboard focus, has no role=tooltip or aria-describedby, and every instance adds scroll and resize listeners while it's open.">
          <LiquidToolbar />
          <LiquidToolbar placement="bottom" />
        </Variant>
        <Variant label="Same toolbar with our shadcn Tooltip" lib="shadcn/ui (Base UI)" hint="For comparison: it opens on focus, is announced, and has collision handling. Use RareUI's only on mouse-first marketing pages.">
          <ShadcnToolbar />
        </Variant>
        <Variant label="Floating navigation in a phone frame" lib={RARE} hint="Has tablist/tab roles and arrow keys, but the icon buttons have no accessible name (the label only shows in the hover tooltip), and the focus ring is removed on purpose. Upstream has no onChange; we added one so the screen can follow it.">
          <PhoneWithNav />
        </Variant>
      </Section>

      <Findings
        title="What we found: 21st.dev vs RareUI"
        notes={[
          {
            tone: "bad",
            text: "21st.dev now gates every registry install, even shadcn's own button, behind an account. The free tier is two copies a day, and the main flow is 'Copy prompt' for a coding agent. Without an account it's a catalogue: preview, usage snippet and dependency list, but no source. That makes it hard to review code before it's in the repo.",
          },
          {
            tone: "bad",
            text: "Quality and licences vary by author, and the listing isn't always right. The Prism UI pricing block is labelled MIT on 21st.dev, but its upstream repo is AGPL-3.0. The liquid glass button lists no licence. The hero lists next as a dependency. Several picks use framer-motion or @radix-ui/react-slot, so they'd need porting to motion/react and Base UI's render prop.",
          },
          {
            tone: "good",
            text: "The workaround that worked: use 21st.dev to find things, then install from the author's own open registry when there is one. blocks.so's stats-05 installed cleanly from blocks.so/r/stats-05.json: no login, no new dependencies, plain shadcn Card. It was fine for an admin dashboard, apart from viewport breakpoints and hard-coded data.",
          },
          {
            tone: "good",
            text: "RareUI is MIT, small enough to read in a minute, and clean: no network calls, eval or tracking in the three files, and it already imports motion/react. It's maintained by one person (49 stars, last push on 2026-11-16). It has been renamed ShitUI: the GitHub repo and shitui.in use the new name. rareui.in's homepage still loads, but its docs links (including the rename notice) return 404.",
          },
          {
            tone: "bad",
            text: "RareUI's components are polished for looks but not ready for production. They have hard-coded layoutIds (two instances interfere), no visible focus, missing ARIA, hover-only tooltips, an uncontrolled nav with no onChange, and fixed positioning baked in. Budget a patch pass for each one; the tabs took about 20 lines.",
          },
          {
            tone: "note",
            text: "Recommendation: keep both in the Playbook, scoped narrowly. 21st.dev is a discovery tool: find a component, check its licence upstream, and install from the source registry, not 21st.dev. RareUI is for marketing and landing-page flourishes (tabs, tooltips, nav), copied by hand and patched for a11y. Don't use either for admin-portal controls; shadcn/Base UI already covers those accessibly.",
          },
        ]}
      />
    </Page>
  )
}
