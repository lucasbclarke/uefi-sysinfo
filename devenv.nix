{ pkgs, lib, config, inputs, ... }:
{
    languages.zig = {
        enable = true;
        version = "0.14.0";
        lsp.enable = false;
    };
}
