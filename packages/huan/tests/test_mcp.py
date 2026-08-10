class TestApprovePolicy:
    def cases(self):
        from huan.mcp_server import approve_decision

        return approve_decision

    def test_routine_network_commands_allowed(self):
        approve = self.cases()
        for cmd in (
            "curl -s wttr.in/Valparaiso?format=3",
            "systemctl --user status huan",
            "journalctl --user -u huan --since -1h",
            "gcalcli agenda",
            "himalaya envelope list -s 10",
        ):
            decision = approve("Bash", {"command": cmd})
            assert decision["behavior"] == "allow", cmd
            assert decision["updatedInput"] == {"command": cmd}

    def test_destructive_commands_denied(self):
        approve = self.cases()
        for cmd in (
            "sudo systemctl restart huan",
            "rm -rf /home/pat/Projects/khanelivim",
            "rm -r build",
            "git push origin main",
            "git -C /home/pat/telperion push origin main",
            "dd if=/dev/zero of=/dev/sda",
            "mkfs.ext4 /dev/sda1",
            "systemctl restart display-manager",
            "shutdown now",
        ):
            assert approve("Bash", {"command": cmd})["behavior"] == "deny", cmd

    def test_non_bash_tools_allowed(self):
        approve = self.cases()
        decision = approve("WebFetch", {"url": "https://wttr.in"})
        assert decision["behavior"] == "allow"
