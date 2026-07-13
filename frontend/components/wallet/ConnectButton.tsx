"use client";

import { ConnectButton as RKConnectButton } from "@rainbow-me/rainbowkit";
import { shortAddress } from "@/lib/utils";

export function ConnectButton() {
  return (
    <RKConnectButton.Custom>
      {({ account, chain, openAccountModal, openChainModal, openConnectModal, mounted }) => {
        const ready = mounted;
        const connected = ready && account && chain;

        return (
          <div
            {...(!ready && {
              "aria-hidden": true,
              style: { opacity: 0, pointerEvents: "none", userSelect: "none" },
            })}
          >
            {!connected ? (
              <button onClick={openConnectModal} className="btn-primary">
                Connect Wallet
              </button>
            ) : chain.unsupported ? (
              <button
                onClick={openChainModal}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-md bg-red-500/10 border border-red-500/30 text-red-400 text-sm font-medium hover:bg-red-500/20 transition-colors"
              >
                ⚠ Wrong Network
              </button>
            ) : (
              <div className="flex items-center gap-2">
                {/* Chain indicator */}
                <button
                  onClick={openChainModal}
                  className="hidden sm:flex items-center gap-1.5 px-3 py-2 rounded-md bg-[#14110D] border border-[#2A241B] text-xs font-mono text-[#A89F8D] hover:border-cyan/30 hover:text-[#F4EFE6] transition-all"
                >
                  {chain.hasIcon && chain.iconUrl && (
                    <img
                      alt={chain.name ?? "Chain icon"}
                      src={chain.iconUrl}
                      className="w-3.5 h-3.5 rounded-full"
                    />
                  )}
                  {chain.name}
                </button>

                {/* Account button */}
                <button
                  onClick={openAccountModal}
                  className="flex items-center gap-2 px-3 py-2 rounded-md bg-[#14110D] border border-[#2A241B] hover:border-cyan/30 transition-all group"
                >
                  {/* Balance */}
                  {account.displayBalance && (
                    <span className="hidden md:block font-mono text-xs text-[#A89F8D] group-hover:text-[#F4EFE6] transition-colors">
                      {account.displayBalance}
                    </span>
                  )}
                  {/* Address */}
                  <span className="font-mono text-xs text-[#F4EFE6]">
                    {shortAddress(account.address)}
                  </span>
                  {/* Avatar */}
                  <div className="w-5 h-5 rounded-full bg-gradient-to-br from-cyan/40 to-violet/40 flex-shrink-0" />
                </button>
              </div>
            )}
          </div>
        );
      }}
    </RKConnectButton.Custom>
  );
}