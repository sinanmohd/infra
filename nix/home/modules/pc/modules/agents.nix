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

    # NOTE comments

    When writing a NOTE comment in any file, format it as
    `NOTE: [AGENT]: <text>` instead of plain `NOTE: <text>`, in whatever
    comment syntax the language uses (`# NOTE: [AGENT]:`,
    `// NOTE: [AGENT]:`, etc.). Bare `NOTE:` comments are written by the
    user, so the tag keeps agent-written notes easy to spot, audit or strip.

    Only tag notes you write, never add the tag to existing `NOTE:`
    comments. Leave other comment kinds (`TODO:`, `FIXME:`, `XXX:`) alone.

    When the user removes the `[AGENT]` tag from a note, they have adopted
    it as their own. Rewrap that comment so its lines fill up to the 80
    character limit again, since dropping the tag leaves the first line
    short. Only change line breaks, keep the wording as it is.

    # Commit subject

    Write commit subjects as `type(scope): summary`, for example:

        feat(nix/pkgs/claude-code): bind ssh known_hosts and config

    - type is `feat` for new behaviour, `fix` for bug fixes and `chore`
      for maintenance (lock bumps, clean ups, renames)
    - scope names the logical unit the change belongs to, like
      `chore(repo): init`. It often looks like a path, but it is not one:
      `nix/home/pc/agents` is the agents unit even though the file lives
      at `nix/home/modules/pc/modules/agents.nix`. When a change spans
      several units, use their common parent (`feat(nix): ...`)
    - summary is short, lowercase and has no trailing period, using plain
      verbs like `init`, `add`, `bump`, `update`, `clean up`

    # Commit description

    Keep short commit descriptions as they are. When a description runs
    longer than a few lines, start it with an unnamed TLDR for humans: a
    few plain sentences on what changed and why, with no `TLDR:` label.
    After it, optionally add a section named `Context Dump` for agents,
    holding the full detail (context, reasoning, alternatives considered,
    file-by-file notes). In a PR description, make it collapsible with
    `<details><summary>Context Dump</summary>`. Git commit descriptions
    are plain text and cannot collapse, so there it is a plain
    `Context Dump:` heading.

    Example:

        feat(nix/home/pc): init agents

        Share one context between claude-code and opencode so both agents
        follow the same rules for missing commands and attribution.

        Context Dump:

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
