{ pkgs, inputsSinan, ... }:
let
  pkgsSinan = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system};

  context = ''
    # Missing commands

    If a command is not installed, run it from nixpkgs with nix instead of
    giving up or looking for another tool:

        nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#<package> -c <command> <args>

    For example:

        nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#python3 -c python3 script.py

    The `--extra-experimental-features` flag is needed on every nix call

    A command missing from PATH does not mean there is none, every package
    in nixpkgs is available. To find which packages provide a command, or
    to answer what is available (like "what versions of python do you
    have"), list them with nix-locate:

        nix-locate --minimal --at-root --regex '/bin/python[0-9.]*$'

    # Commit description

    Keep short commit descriptions as they are. When a description runs
    longer than a few lines, start it with a TLDR paragraph written for
    humans: a few plain sentences on what changed and why. After the TLDR,
    add the full detail (context, reasoning, alternatives considered,
    file-by-file notes) for readers who want it.

    Example:

        feat(nix/home/pc): init agents

        TLDR: Share one context between claude-code and opencode so both
        agents follow the same rules for missing commands and attribution.

        Previously opencode had its own module with a separate context...

    # Attribution

    When AI tools contribute to a change, proper attribution helps track the
    role of AI in the development process. Contributions should include an
    Assisted-by tag in the commit message, in the following format:

        Assisted-by: AGENT_NAME:MODEL_VERSION [TOOL1] [TOOL2]

    Where:

    - AGENT_NAME is the name of the AI tool or framework
    - MODEL_VERSION is the specific model version used
    - [TOOL1] [TOOL2] are optional specialized analysis tools used (e.g.,
      coccinelle, sparse, smatch, clang-tidy)

    Basic development tools (git, gcc, make, editors) should not be listed.

    Never add a Co-Authored-By trailer, the Assisted-by tag replaces it.

    Example:

        Assisted-by: OpenCode:Kimi-K3 coccinelle sparse
  '';
in
{
  programs.claude-code = {
    enable = true;
    package = pkgsSinan.claude-code;
    inherit context;
  };

  programs.opencode = {
    enable = true;
    package = pkgsSinan.opencode;
    tui.theme = "system";
    inherit context;
  };
}
