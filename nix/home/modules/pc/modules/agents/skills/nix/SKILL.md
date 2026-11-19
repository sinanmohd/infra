---
name: nix
description: >-
  Conventions for writing Nix code. Use when writing Nix flakes,
  derivations, nixpkgs packages, devShells, NixOS or Home Manager
  modules, or nix library functions.
metadata:
  author: sinanmohd
---

# Nix

## Doc comments

Document every nix function you write or change with a doc comment in
the style nixpkgs uses in `lib/` (RFC 145), placed directly above the
binding:

```nix
  /**
    Split a multi document yaml into a json list of objects, empty
    documents (like a trailing `---`) are dropped.

    # Inputs

    `name`

    : Name of the derivation, `.json` is appended

    `src`

    : Path to the multi document yaml

    # Type

    ```
    toJsonList :: String -> Path -> Derivation
    ```
  */
  toJsonList =
    name: src:
    pkgs.runCommand "${name}.json" { } ''
      ...
    '';
```

### Layout

The comment opens with `/**` and closes with `*/`, both on their own
line at the indentation of the binding. The text inside is indented two
more spaces and wrapped at 80 columns.

1. **Description**: what the function does, in plain sentences. Put
   the why here too when it is not obvious, like why a label goes on
   every item instead of the list. This replaces a separate `# NOTE:`
   comment on the function, do not keep both.
2. **`# Inputs`**: one entry per argument, in the order the function
   takes them. The argument name in backticks on its own line, a blank
   line, then the description as a markdown definition, a line starting
   with a colon and a space.
3. **`# Type`**: the signature in a fenced block without a language,
   named after the binding, like `toJsonList :: String -> Path ->
   Derivation`.
4. **`# Examples`** (optional): add one when the input or output shape
   is not obvious from the type, in the nixpkgs form:

   ````markdown
   # Examples
   :::{.example}
   ## `toJsonList` usage example

   ```nix
   toJsonList "demo" ./demo.yaml
   => «derivation /nix/store/...-demo.json.drv»
   ```

   :::
   ````

Leave out a section only when it would be empty, like `# Inputs` for a
binding that is not a function.

### Types

Use the names nixpkgs uses in its signatures:

- `String`, `Int`, `Bool`, `Path`, `Derivation`, `Null`, `Any`
- `AttrSet` for an attrset with no useful shape to describe, or the
  shape when it helps, like `{ name :: String; value :: a; }`
- `{ [String] :: a }` for an attrset of uniform values
- `[a]` for lists, `a -> b` for functions, lowercase letters for
  generic types
- `a | b` when an argument takes either

### Attrset arguments

For a function taking an attrset (`{ name, src, ... }:`), describe the
fields under one entry:

```nix
  /**
    Build the json for an addon.

    # Inputs

    `args`

    : An attribute set containing:

      `name`

      : Name of the derivation

      `src`

      : Path to the multi document yaml

    # Type

    ```
    mkAddon :: { name :: String; src :: Path; } -> Derivation
    ```
  */
```

### Scope

- Document functions you add, and functions whose behaviour or
  arguments you change. Do not add doc comments to untouched functions
  in a file unless asked.
- Doc comments are read by tooling, so they take no comment tag and no
  `[AGENT]`, unlike regular comments.
- Module option `description`s are not functions, keep using
  `description` and `example` there.
- Never rewrite doc comments the user wrote, beyond updating them to
  match a change you made to the function.
- Run `nixfmt` on the file afterwards, it leaves the comment text alone
  but fixes the binding around it.
