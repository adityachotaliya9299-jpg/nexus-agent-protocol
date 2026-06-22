import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";

const projectId = process.env.NEXT_PUBLIC_WC_PROJECT_ID ?? "nexus-agent-protocol";

export const wagmiConfig = getDefaultConfig({
  appName: "Nexus Agent Protocol",
  projectId,
  chains: [sepolia],
  ssr: true,
});

export { sepolia };