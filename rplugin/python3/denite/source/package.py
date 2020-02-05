# ============================================================================
# FILE: package.py
# AUTHOR: Bakudankun <bakudankun at gmail.com>
# License: MIT license
# ============================================================================

from denite.base.source import Base
from denite.util import Nvim, UserContext, Candidates
from os import environ, path


PACKAGE_HIGHLIGHT_SYNTAX = [
    {"name": "Head", "link": "Directory", "re": r".*[\/]"},
]


class Source(Base):
    def __init__(self, vim: Nvim) -> None:
        super().__init__(vim)

        self.vim = vim
        self.name = "package"
        self.kind = "package"
        self.converters = ["converter/relative_abbr", "converter/tail_path"]

    def define_syntax(self) -> None:
        super().define_syntax()
        for syn in PACKAGE_HIGHLIGHT_SYNTAX:
            self.vim.command(
                "syntax match {0}_{1} /{2}/ contained containedin={0}".format(
                    self.syntax_name, syn["name"], syn["re"]
                )
            )

    def highlight(self) -> None:
        super().highlight()
        for syn in PACKAGE_HIGHLIGHT_SYNTAX:
            self.vim.command(
                "highlight default link {}_{} {}".format(
                    self.syntax_name, syn["name"], syn["link"]
                )
            )

    def gather_candidates(self, context: UserContext) -> Candidates:
        packages = self.vim.eval("globpath(&packpath, 'pack/*/*/*', 1, 1)")

        return [{"word": package, "action__path": package} for package in packages]
