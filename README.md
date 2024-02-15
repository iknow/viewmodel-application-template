# README

This template Rails application provides a starting point for developing a
new Rails API application using the
[https://github.com/iknow/iknow_view_models/](`iknow_view_models`) library.

For our internal purposes, it also serves as a guide for what parts of our main
application itself should be abstracted and extracted into shared library code
before we want to maintain more than one application based on it. The majority
of the code in this repository is general-purpose, and could be migrated either
to the`iknow_view_models` gem itself or to a new common library, in order that
we don't rapidly diverge from the initial template.
