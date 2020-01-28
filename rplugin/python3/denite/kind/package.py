# ============================================================================
# FILE: package.py
# AUTHOR: Bakudankun <bakudankun at gmail.com>
# License: MIT license
# ============================================================================

from denite.kind.directory import Kind as Base
from denite.util import Nvim, UserContext
from os import path


class Kind(Base):
    def __init__(self, vim: Nvim) -> None:
        super().__init__(vim)

        self.name = "package"
        self.default_action = "packadd"

    def action_packadd(self, context: UserContext) -> None:
        for target in context["targets"]:
            packname = path.split(target["action__path"])[1]
            self.vim.command("packadd " + packname)

    def action_helptags(self, context: UserContext) -> None:
        for target in context["targets"]:
            docdir = path.join(target["action__path"], "doc")
            self.vim.command("helptags " + docdir)
