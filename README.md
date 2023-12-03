# README

This extracted skeleton template provides a starting point for developing a
Replace-like ViewModels API Rails application.

It also serves as a guide for what parts of the Replace application itself
should be abstracted and extracted into shared library code before we want to
maintain more than one application based on it. The majority of the code in this
repository is general-purpose, and could be migrated either to the
`iknow_view_models` gem itself or to a new `replace-common` library.
