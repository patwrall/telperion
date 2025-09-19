{
  config = {
    programs = {
      zellij = {
        layouts = {
          system = {
            layout = {
              _children = [
                {
                  default_tab_template = {
                    _children = [
                      {
                        pane = {
                          size = 1;
                          borderless = true;
                          plugin = {
                            location = "zellij:tab-bar";
                          };
                        };
                      }
                      { "children" = { }; }
                      {
                        pane = {
                          size = 2;
                          borderless = true;
                          plugin = {
                            location = "zellij:status-bar";
                          };
                        };
                      }
                    ];
                  };
                }
                {
                  tab_template = {
                    _props = {
                      name = "dev_tab";
                    };
                    _children = [
                      {
                        pane = {
                          size = 1;
                          borderless = true;
                          plugin = {
                            location = "zellij:tab-bar";
                          };
                        };
                      }
                      {
                        pane = {
                          split_direction = "Vertical";
                          _children = [
                            {
                              pane = {
                                size = "15%";
                                _props = {
                                  name = "Filetree";
                                };
                                plugin = {
                                  location = "zellij:strider";
                                };
                              };
                            }
                          ];
                        };
                      }
                      { "children" = { }; }
                      {
                        pane = {
                          size = 2;
                          borderless = true;
                          plugin = {
                            location = "zellij:status-bar";
                          };
                        };
                      }
                    ];
                  };
                }
                {
                  pane_template = {
                    _props = {
                      name = "term";
                    };
                    _children = [
                      {
                        pane = {
                          split_direction = "horizontal";
                          _children = [
                            { "children" = { }; }
                            {
                              pane = {
                                command = "fish";
                                size = "25%";
                                _props = {
                                  name = "Shell";
                                };
                              };
                            }
                          ];
                        };
                      }
                    ];
                  };
                }
                {
                  tab = {
                    _props = {
                      name = "telperion";
                      focus = true;
                      cwd = "$HOME/telperion/";
                    };
                    _children = [
                      {
                        pane = {
                          command = "nvim";
                        };
                      }
                    ];
                  };
                }
                {
                  tab = {
                    _props = {
                      name = "Git";
                      split_direction = "horizontal";
                      cwd = "$HOME/telperion/";
                    };
                    _children = [
                      {
                        pane = {
                          command = "lazygit";
                        };
                      }
                    ];
                  };
                }
                {
                  tab = {
                    _props = {
                      name = "Files";
                      split_direction = "horizontal";
                      cwd = "$HOME";
                    };
                    _children = [
                      {
                        pane = {
                          # Get at least some image previews in zellij
                          command = "sh";
                          args = [
                            "-c"
                            "TERM=foot yazi"
                          ];
                        };
                      }
                    ];
                  };
                }
                {
                  tab = {
                    _props = {
                      name = "Shell";
                      split_direction = "horizontal";
                      cwd = "$HOME/telperion/";
                    };
                    _children = [
                      {
                        pane = {
                          command = "fish";
                        };
                      }
                    ];
                  };
                }
                {
                  tab = {
                    _props = {
                      name = "Processes";
                      split_direction = "vertical";
                      cwd = "$HOME";
                    };
                    _children = [
                      {
                        pane = {
                          command = "btop";
                        };
                      }
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
