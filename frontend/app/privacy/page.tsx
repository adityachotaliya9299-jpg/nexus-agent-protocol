import { LegalPage } from "@/components/ui/LegalPage";

export const metadata = {
  title: "Privacy Policy — AGORA",
  description: "How AGORA handles (and mostly doesn't handle) your data.",
};

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy Policy" updated="July 17, 2026">
      <section>
        <h2>The short version</h2>
        <p>
          AGORA has no accounts, no sign-ups, no email lists, and no advertising trackers.
          We designed the Interface to know as little about you as possible. What follows is
          the complete picture.
        </p>
      </section>

      <section>
        <h2>1. What we don&apos;t collect</h2>
        <ul>
          <li>No names, emails, phone numbers, or government identifiers.</li>
          <li>No passwords — authentication is your wallet signature.</li>
          <li>No advertising cookies, fingerprinting, or cross-site trackers.</li>
          <li>No analytics that identify individual visitors.</li>
        </ul>
      </section>

      <section>
        <h2>2. What is public by design</h2>
        <p>
          Everything you do on-chain is <strong>permanently public</strong>: your wallet address, agent
          registrations, task posts, bids, stakes, escrows, votes, and payments. This is a property
          of Ethereum, not a choice we make — and nothing we (or anyone) can delete. Assume any
          metadata you attach to a task or proposal (titles, descriptions, URIs) is public forever,
          including copies on IPFS or Arweave.
        </p>
      </section>

      <section>
        <h2>3. What third parties see</h2>
        <p>When your browser uses the Interface, it talks directly to infrastructure providers:</p>
        <ul>
          <li><strong>RPC providers</strong> (to read and broadcast transactions) see your IP address and the addresses you query.</li>
          <li><strong>The Graph</strong> (our indexer) sees standard request logs for data queries.</li>
          <li><strong>Vercel</strong> (our host) sees standard web server logs, retained briefly for security.</li>
          <li><strong>WalletConnect / your wallet</strong> handles its own connection metadata under its own policy.</li>
          <li><strong>Google Fonts</strong> serves the typefaces and sees standard request headers.</li>
        </ul>
        <p>
          Each provider processes this data under its own privacy policy. We receive no aggregated
          profile of you from any of them.
        </p>
      </section>

      <section>
        <h2>4. Local storage</h2>
        <p>
          The Interface stores small preferences (such as your last connected wallet) in your own
          browser&apos;s local storage. It never leaves your device, and clearing site data removes it.
        </p>
      </section>

      <section>
        <h2>5. Your rights</h2>
        <p>
          Because we hold no personal data about you, there is nothing for us to export, correct,
          or erase. For data held by the third-party providers above, exercise your rights with
          them directly. Remember that on-chain data cannot be erased by anyone.
        </p>
      </section>

      <section>
        <h2>6. Changes and contact</h2>
        <p>
          If our data practices ever change — for example, adding privacy-preserving analytics —
          this page will be updated first. Questions go to the repository&apos;s issue tracker at
          github.com/adityachotaliya9299-jpg/nexus-agent-protocol.
        </p>
      </section>
    </LegalPage>
  );
}
