{
  config = {
    programs = {
      zellij = {
        settings = {
          keybinds = {
            # This clears all default keybindings to start fresh.
            # _props.clear-defaults = true;

            # Keybindings for the "locked" mode (Vim's normal mode equivalent)
            locked = {
              _children = [
                # Pane Navigation using Alt + hjkl
                {
                  bind = {
                    _args = [ "Alt h" ];
                    _children = [ { MoveFocus._args = [ "Left" ]; } ];
                  };
                }
                {
                  bind = {
                    _args = [ "Alt j" ];
                    _children = [ { MoveFocus._args = [ "Down" ]; } ];
                  };
                }
                {
                  bind = {
                    _args = [ "Alt k" ];
                    _children = [ { MoveFocus._args = [ "Up" ]; } ];
                  };
                }
                {
                  bind = {
                    _args = [ "Alt l" ];
                    _children = [ { MoveFocus._args = [ "Right" ]; } ];
                  };
                }

                # Pane Management (like :split and :vsplit)
                {
                  bind = {
                    _args = [ "Alt n" ];
                    _children = [ { NewPane = { }; } ];
                  };
                } # New pane below (horizontal split)
                {
                  bind = {
                    _args = [ "Alt v" ];
                    _children = [ { NewPane._props.direction = "Right"; } ];
                  };
                } # New pane to the right (vertical split)
                {
                  bind = {
                    _args = [ "Alt x" ];
                    _children = [ { CloseFocus = { }; } ];
                  };
                } # Close focused pane
                {
                  bind = {
                    _args = [ "Alt z" ];
                    _children = [ { ToggleFocusFullscreen = { }; } ];
                  };
                } # Zoom/unzoom pane

                # Tab Management
                {
                  bind = {
                    _args = [ "Alt t" ];
                    _children = [ { NewTab = { }; } ];
                  };
                } # New tab

                # Ctrl+Space for tab navigation mode
                {
                  bind = {
                    _args = [ "Ctrl Space" ];
                    _children = [ { SwitchToMode._args = [ "Pane" ]; } ];
                  };
                }

                # Enter other modes
                {
                  bind = {
                    _args = [ "Alt s" ];
                    _children = [ { SwitchToMode._args = [ "Scroll" ]; } ];
                  };
                }
                {
                  bind = {
                    _args = [ "Alt r" ];
                    _children = [ { SwitchToMode._args = [ "RenamePane" ]; } ];
                  };
                }
              ];
            };

            # Keybindings for "pane" mode (tab navigation with numbers)
            pane = {
              _children = [
                {
                  bind = {
                    _args = [ "1" ];
                    _children = [
                      { GoToTab._args = [ 1 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "2" ];
                    _children = [
                      { GoToTab._args = [ 2 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "3" ];
                    _children = [
                      { GoToTab._args = [ 3 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "4" ];
                    _children = [
                      { GoToTab._args = [ 4 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "5" ];
                    _children = [
                      { GoToTab._args = [ 5 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "6" ];
                    _children = [
                      { GoToTab._args = [ 6 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "7" ];
                    _children = [
                      { GoToTab._args = [ 7 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "8" ];
                    _children = [
                      { GoToTab._args = [ 8 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "9" ];
                    _children = [
                      { GoToTab._args = [ 9 ]; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
                {
                  bind = {
                    _args = [ "Space" ];
                    _children = [ { SwitchToMode._args = [ "Locked" ]; } ];
                  };
                }
              ];
            };

            # Keybindings for "scroll" mode (for scrolling up/down the buffer)
            scroll = {
              _children = [
                {
                  bind = {
                    _args = [
                      "j"
                      "Down"
                    ];
                    _children = [ { ScrollDown = { }; } ];
                  };
                }
                {
                  bind = {
                    _args = [
                      "k"
                      "Up"
                    ];
                    _children = [ { ScrollUp = { }; } ];
                  };
                }
                {
                  bind = {
                    _args = [
                      "q"
                      "Esc"
                    ];
                    _children = [ { SwitchToMode._args = [ "Locked" ]; } ];
                  };
                }
              ];
            };

            # Keybindings for renaming a pane
            renamepane = {
              _children = [
                {
                  bind = {
                    _args = [ "Enter" ];
                    _children = [ { SwitchToMode._args = [ "Locked" ]; } ];
                  };
                }
                {
                  bind = {
                    _args = [ "Esc" ];
                    # This demonstrates multiple actions for a single bind
                    _children = [
                      { UndoRenamePane = { }; }
                      { SwitchToMode._args = [ "Locked" ]; }
                    ];
                  };
                }
              ];
            };
          };
        };
      };
    };
  };
}
