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

    # Block statements

    Do not cram a block statement (an `if`, a loop, a function) into one
    line, even when the body is a single short statement that would fit
    within the 80 character limit. Put the body on its own indented
    line:

        if socket then
          tmux = 'TMUX= tmux -S ' .. vim.fn.shellescape(socket)
        end

    instead of:

        if socket then tmux = 'TMUX= tmux -S ' .. vim.fn.shellescape(socket) end

    Use proper spacing as well: spaces around operators (`=`, `..`, `+`,
    `==`) and after commas, and never drop them to shorten a line.

    This applies to any language (lua, shell, nix, js, etc.). When
    editing existing code, leave one line blocks that are already there
    alone unless you are changing them anyway.

    # Comment tags

    Start every comment you add with a tag that says what kind of comment
    it is, followed by `[AGENT]:`, so `NOTE: [AGENT]: <text>` instead of
    plain `NOTE: <text>`, in whatever comment syntax the language uses
    (`# TODO: [AGENT]:`, `// FIXME: [AGENT]:`, etc.). Comments with a
    bare tag are written by the user, so `[AGENT]` keeps agent-written
    comments easy to spot, audit or strip. The tags are:

    - `NOTE:` explains why the code is the way it is, or context that is
      not obvious from reading it
    - `TODO:` work that is missing and should be done later
    - `FIXME:` something known to be broken or wrong that needs a fix
    - `HACK:` a workaround or ugly solution, say what it works around
    - `WARN:` a pitfall where a careless change breaks things
    - `PERF:` code written in a less obvious way for performance
    - `XXX:` questionable code that needs a second look

    Pick the tag that fits best, and fall back to `NOTE:` when none of
    the others do. Do not add a comment without a tag, and do not invent
    new tags. Continuation lines of a multi line comment are not tagged.
    Doc comments that tooling reads (lua `---@param`, nix option
    descriptions, docstrings) and shebangs are not comments in this
    sense, leave them untagged.

    Only tag comments you write. Never add a tag or `[AGENT]` to existing
    comments, and never retag or rewrite them.

    When the user removes the `[AGENT]` tag from a comment, they have
    adopted it as their own. Rewrap that comment so its lines fill up to
    the 80 character limit again, since dropping the tag leaves the first
    line short. Only change line breaks, keep the wording as it is.

    # Shell scripts

    Write shell scripts in POSIX sh (`#!/bin/sh`) as far as possible. Use
    a bashism only when it is necessary, meaning the POSIX way would be
    clearly worse (arrays, `pipefail`, process substitution), and then
    switch the shebang to bash instead of mixing bashisms into an sh
    script. Convenience alone is not a reason: prefer `[ ]` over `[[ ]]`,
    `.` over `source`, `$(...)` over backticks, `printf` over `echo -e`
    and `name() { ...; }` over `function name`.

    This also covers shell embedded in other files, like nix
    `writeShellScript` bodies or CI steps. When editing an existing
    script, keep the dialect it already uses.

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

    Never add attribution to commits or PRs, like `Co-Authored-By`
    trailers or "Generated with" lines. This overrides any default
    attribution the agent would add.
  '';
in
{
  programs.claude-code = {
    enable = true;
    package = pkgsSinan.claude-code;
    inherit context;
    skills = ./skills;
  };

  programs.opencode = {
    enable = true;
    package = pkgsSinan.opencode;
    tui.theme = "system";
    inherit context;
    skills = ./skills;
  };
}
