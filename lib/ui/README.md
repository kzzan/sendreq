# UI modules

Flutter presentation is organized by the three user tools, not by transport.

- `core`: Chakra tokens, recipes, shared controls, and PC layout primitives.
- `shell`: application rail, top context bar, workspace composition, and UI controllers.
- `features/requests`: Collection, Environment, editor, and current output.
- `features/mock`: HTTP-only Mock presentation.
- `features/settings`: local preference presentation.

Dependencies point from UI to domain contracts. Concrete data adapters are
created only by `app` and injected into the UI composition root.

Leaf tools (`mock` and `settings`) receive immutable feature projections and
explicit commands. They must not import `ui/shell`; Shell maps its coordinated
state into those contracts. Requests remains the coordinated multi-protocol
workflow and is decomposed internally by collection, editor, environment,
output, and WebSocket responsibility.
