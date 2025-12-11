# Terminal Graphics Integration Plan (Philo → grey::static)

**Status:** In Progress
**Start Date:** 2025-12-11
**Target Feature:** `tty::graphics`
**Source:** `/Users/stevan/Projects/perl/Philo`

---

## Executive Summary

Integration of Philo terminal graphics framework into grey::static as the `tty::graphics` sub-feature. This provides high-level graphics abstractions (shaders, sprites, drawing primitives) built on top of the existing `tty::ansi` foundation.

### Goals
- ✅ Provide shader-based terminal rendering capabilities
- ✅ Enable sprite graphics with transformations
- ✅ Integrate with existing grey::static features (datatypes::numeric, functional, stream)
- ✅ Maintain clean separation: `tty::ansi` (control) → `tty::graphics` (rendering)
- ✅ Follow grey::static conventions (lexical exports, sub-feature pattern)

---

## Architecture Overview

### Integration Point
```perl
use grey::static qw[
    tty::ansi      # Low-level: cursor, colors, screen control
    tty::graphics  # High-level: shaders, sprites, rendering
];
```

### Directory Structure
```
lib/grey/static/tty/graphics/
├── Graphics.pm                    # Main module (lexical exports)
├── Graphics/Shader.pm             # Core rendering engine
├── Graphics/Sprite.pm             # 2D bitmap graphics
├── Graphics/Point.pm              # Coordinate class
├── Graphics/Color.pm              # RGB color class
├── Graphics/Tools/
│   ├── Shaders.pm                # Utility functions
│   └── ArrowKeys.pm              # Keyboard input
└── Graphics/Roles/
    ├── Drawable.pm               # Interface for drawable objects
    └── Oriented.pm               # Interface for directional objects

t/grey/static/06-tty/
├── 020-graphics-point.t          # Point class tests
├── 021-graphics-color.t          # Color class tests
├── 022-graphics-shader.t         # Shader rendering tests
├── 023-graphics-sprite.t         # Sprite tests
├── 024-graphics-tools.t          # Utility functions tests
└── 025-graphics-integration.t    # Integration with other features
```

### Module Mapping

| Philo Class | grey::static Class | Export Name |
|-------------|-------------------|-------------|
| `Philo::Shader` | `grey::static::tty::graphics::Graphics::Shader` | `Graphics::Shader` |
| `Philo::Sprite` | `grey::static::tty::graphics::Graphics::Sprite` | `Graphics::Sprite` |
| `Philo::Point` | `grey::static::tty::graphics::Graphics::Point` | `Graphics::Point` |
| `Philo::Color` | `grey::static::tty::graphics::Graphics::Color` | `Graphics::Color` |
| `Philo::Tools::Shaders` | `grey::static::tty::graphics::Graphics::Tools::Shaders` | Functions only |
| `Philo::Tools::ArrowKeys` | `grey::static::tty::graphics::Graphics::Tools::ArrowKeys` | `Graphics::ArrowKeys` |

---

## Implementation Phases

### Phase 1: Core Graphics Classes ⬅️ **CURRENT**

**Goal:** Port fundamental classes and establish integration patterns

#### Tasks
- [ ] 1.1: Create `lib/grey/static/tty/graphics/Graphics.pm` main module
  - [ ] Implement lexical export pattern
  - [ ] Load all Graphics::* classes
  - [ ] Export constructors and utility functions

- [ ] 1.2: Port `Philo::Point` → `Graphics::Point`
  - [ ] Port class to `lib/grey/static/tty/graphics/Graphics/Point.pm`
  - [ ] Update Perl version to v5.42
  - [ ] Remove Philo-specific code
  - [ ] Create test: `t/grey/static/06-tty/020-graphics-point.t`

- [ ] 1.3: Port `Philo::Color` → `Graphics::Color`
  - [ ] Port class to `lib/grey/static/tty/graphics/Graphics/Color.pm`
  - [ ] Update Perl version to v5.42
  - [ ] Remove Philo-specific code
  - [ ] Create test: `t/grey/static/06-tty/021-graphics-color.t`

- [ ] 1.4: Port `Philo::Tools::Shaders` → `Graphics::Tools::Shaders`
  - [ ] Port utility functions to `lib/grey/static/tty/graphics/Graphics/Tools/Shaders.pm`
  - [ ] Export functions lexically (fract, distance, smoothstep, mix, etc.)
  - [ ] Create test: `t/grey/static/06-tty/024-graphics-tools.t`

- [ ] 1.5: Port `Philo::Shader` → `Graphics::Shader`
  - [ ] Port class to `lib/grey/static/tty/graphics/Graphics/Shader.pm`
  - [ ] **REFACTOR:** Replace direct ANSI codes with `tty::ansi` calls
  - [ ] Update coordinate system constants
  - [ ] Create test: `t/grey/static/06-tty/022-graphics-shader.t`

- [ ] 1.6: Update `lib/grey/static/tty.pm` router
  - [ ] Add 'graphics' subfeature handler
  - [ ] Load Graphics.pm and call its import()

- [ ] 1.7: Integration testing
  - [ ] Test basic shader rendering
  - [ ] Test tty::ansi integration
  - [ ] Verify lexical exports work correctly

**Success Criteria:**
- ✅ Can load `use grey::static qw[ tty::graphics ];`
- ✅ Point, Color, Shader classes work
- ✅ Basic shader rendering produces output
- ✅ All ANSI operations go through tty::ansi (no direct `\e[` codes)
- ✅ All Phase 1 tests pass

---

### Phase 2: Sprite System with Matrix Integration

**Goal:** Add sprite graphics with Matrix datatype integration

#### Tasks
- [ ] 2.1: Design Matrix-backed sprite storage
  - [ ] Decide on representation (single 3-channel tensor vs. 3 separate matrices)
  - [ ] Plan conversion between Matrix ↔ Color objects

- [ ] 2.2: Port `Philo::Sprite` → `Graphics::Sprite`
  - [ ] Port to `lib/grey/static/tty/graphics/Graphics/Sprite.pm`
  - [ ] **REFACTOR:** Replace array storage with Matrix
  - [ ] Implement Matrix-based transformations
  - [ ] Add `from_matrix()` constructor

- [ ] 2.3: Add Matrix integration methods
  - [ ] `to_matrix()` - Export sprite as Matrix
  - [ ] `from_matrix()` - Import Matrix as sprite
  - [ ] Transformation methods using Matrix operations

- [ ] 2.4: Port sprite transformation operations
  - [ ] `flip()` - Vertical flip using Matrix transpose
  - [ ] `mirror()` - Horizontal flip
  - [ ] Additional transformations (rotate, scale)

- [ ] 2.5: Implement sprite rendering
  - [ ] `draw_at($point)` method
  - [ ] Integration with Shader rendering pipeline
  - [ ] Test with various sprite sizes

- [ ] 2.6: Create comprehensive tests
  - [ ] Test: `t/grey/static/06-tty/023-graphics-sprite.t`
  - [ ] Test sprite creation, transformations, rendering
  - [ ] Test Matrix conversion round-trips

**Success Criteria:**
- ✅ Sprites use Matrix for internal storage
- ✅ All transformations work correctly
- ✅ Can convert between sprite and Matrix representations
- ✅ Sprite rendering integrates with shader system
- ✅ All Phase 2 tests pass

**Dependencies:** Phase 1 complete, datatypes::numeric available

---

### Phase 3: Input Handling

**Goal:** Add keyboard input with functional integration

#### Tasks
- [ ] 3.1: Port `Philo::Tools::ArrowKeys` → `Graphics::Tools::ArrowKeys`
  - [ ] Port to `lib/grey/static/tty/graphics/Graphics/Tools/ArrowKeys.pm`
  - [ ] Keep Term::ReadKey integration
  - [ ] Update Perl version to v5.42

- [ ] 3.2: **REFACTOR:** Add functional callback system
  - [ ] Replace receiver object pattern with Consumer callbacks
  - [ ] Add `on_up()`, `on_down()`, `on_left()`, `on_right()` methods
  - [ ] Add generic `on_direction()` with BiConsumer
  - [ ] Maintain backward compatibility with receiver objects

- [ ] 3.3: Explore mouse integration
  - [ ] Research integration with existing `tty::ansi::ANSI::Mouse`
  - [ ] Design unified input API
  - [ ] Consider event stream approach

- [ ] 3.4: Port Roles
  - [ ] Port `Philo::Roles::Drawable` → `Graphics::Roles::Drawable`
  - [ ] Port `Philo::Roles::Oriented` → `Graphics::Roles::Oriented`
  - [ ] Document role usage patterns (since Perl class/role integration is limited)

- [ ] 3.5: Create input tests
  - [ ] Test arrow key capture
  - [ ] Test functional callbacks
  - [ ] Test receiver object pattern
  - [ ] Integration test with sprite movement

**Success Criteria:**
- ✅ Arrow key input works reliably
- ✅ Both functional and object-oriented patterns supported
- ✅ Input integrates cleanly with animation loops
- ✅ All Phase 3 tests pass

**Dependencies:** Phase 2 complete, functional feature available

---

### Phase 4: Advanced Features

**Goal:** Add layout primitives and higher-level abstractions

#### Tasks
- [ ] 4.1: Design layout system
  - [ ] Box/panel primitives
  - [ ] Border rendering
  - [ ] Nested layout support

- [ ] 4.2: Implement basic widgets
  - [ ] Button widget
  - [ ] Menu/list widget
  - [ ] Text input widget

- [ ] 4.3: Add text rendering
  - [ ] Text rendering within shader contexts
  - [ ] Font/style support (if feasible)
  - [ ] Text alignment utilities

- [ ] 4.4: Animation utilities
  - [ ] Easing functions
  - [ ] Tweening system
  - [ ] Frame interpolation

- [ ] 4.5: Performance optimization
  - [ ] Dirty rectangle tracking
  - [ ] Partial screen updates
  - [ ] Benchmarking and profiling

**Success Criteria:**
- ✅ Can build basic TUI layouts
- ✅ Widgets are composable
- ✅ Animation utilities simplify common patterns
- ✅ Performance is acceptable for typical use cases

**Dependencies:** Phase 3 complete

---

### Phase 5: Examples and Documentation

**Goal:** Provide comprehensive examples and documentation

#### Tasks
- [ ] 5.1: Port Philo examples
  - [ ] Port `t/003-simple-shader.t` → animated shader example
  - [ ] Port `t/100-landscape.t` → 3D landscape demo
  - [ ] Port `t/110-starfield.t` → interactive starfield
  - [ ] Port `t/130-fireworks.t` → particle effects
  - [ ] Update all examples to use grey::static APIs

- [ ] 5.2: Create integration examples
  - [ ] Example: Data visualization with Matrix + Graphics
  - [ ] Example: Stream-based animation pipeline
  - [ ] Example: Interactive TUI application
  - [ ] Example: Real-time data dashboard

- [ ] 5.3: Write comprehensive documentation
  - [ ] API reference for all Graphics classes
  - [ ] Tutorial: Getting started with shaders
  - [ ] Tutorial: Building interactive applications
  - [ ] Tutorial: Sprite graphics and animations

- [ ] 5.4: Update project documentation
  - [ ] Update `CLAUDE.md` with tty::graphics feature
  - [ ] Update `README.md` with graphics examples
  - [ ] Add graphics section to main docs

**Success Criteria:**
- ✅ All Philo examples ported and working
- ✅ Integration examples demonstrate feature combinations
- ✅ Documentation is clear and comprehensive
- ✅ New users can get started quickly

**Dependencies:** Phase 4 complete

---

## Technical Decisions

### 1. Coordinate Systems

**Decision:** Maintain Philo's dual coordinate system approach
- `TOP_LEFT`: (0,0) at top-left, pixel coordinates (0 to width-1, 0 to height-1)
- `CENTERED`: (0,0) at center, normalized coordinates (-1 to 1)

**Rationale:** Provides flexibility for different use cases (UI vs. mathematical visualization)

### 2. ANSI Integration

**Decision:** Refactor all direct ANSI escape codes to use `tty::ansi`
- `Shader->clear_screen()` calls `ANSI::Screen::clear_screen()`
- `Shader->hide_cursor()` calls `ANSI::Screen::hide_cursor()`
- Color formatting uses `ANSI::Color::format_fg_color()` and `format_bg_color()`

**Rationale:**
- Eliminates code duplication
- Ensures consistency across all tty features
- Easier to maintain and extend

### 3. Sprite Storage

**Decision:** Use Matrix datatype for internal sprite storage

**Implementation Options:**
1. **Three separate matrices** (R, G, B) - SELECTED
   - Easier channel-wise operations
   - More memory but clearer semantics

2. Single 3-channel Tensor (H × W × 3)
   - More compact
   - Requires tensor slicing

**Rationale:** Separate matrices provide clearer API and leverage Matrix operations better

### 4. Perl Version

**Decision:** Upgrade all Philo code from v5.38 to v5.42

**Rationale:** Matches grey::static requirement, ensures compatibility

### 5. Lexical Export Pattern

**Decision:** Use lexical exports for all Graphics classes and utility functions

```perl
use grey::static qw[ tty::graphics ];

# In scope:
Graphics::Shader->new(...);
Graphics::Point->new(10, 20);
my $dist = distance($p1, $p2);  # Utility function
```

**Rationale:** Consistent with grey::static philosophy, prevents namespace pollution

---

## Dependencies and Prerequisites

### External Modules
- `Term::ReadKey` - Already required by `tty::ansi`
- No new external dependencies

### Internal Features
- `tty::ansi` - Required for all terminal operations
- `datatypes::numeric` - Optional but recommended for sprites
- `functional` - Optional but recommended for callbacks
- `stream` - Optional for animation pipelines

### Perl Requirements
- Perl v5.42+ (consistent with grey::static)
- `experimental::class` feature
- `builtin` functions (load_module, export_lexically)

---

## Testing Strategy

### Unit Tests
- Each class gets dedicated test file
- Test all public methods
- Test edge cases (empty sprites, out-of-bounds coordinates, etc.)

### Integration Tests
- Test Graphics + tty::ansi integration
- Test Graphics + datatypes::numeric (sprite/matrix conversion)
- Test Graphics + functional (shader functions, callbacks)
- Test Graphics + stream (animation pipelines)

### Visual/Interactive Tests
- Example programs that produce visible output
- Interactive demos for input handling
- Performance benchmarks for rendering

### Test Coverage Goals
- 90%+ coverage for core classes (Point, Color, Sprite)
- 80%+ coverage for Shader (harder to test rendering)
- 100% coverage for utility functions

---

## Risk Mitigation

### Risk 1: Performance
**Concern:** Shader rendering is CPU-intensive, may be slow on large screens

**Mitigation:**
- Start with reasonable defaults (80x24 or 120x40)
- Add benchmarking early in Phase 1
- Implement optimizations in Phase 4 if needed
- Document performance characteristics

### Risk 2: Coordinate System Complexity
**Concern:** Multiple coordinate systems could confuse users

**Mitigation:**
- Clear documentation with visual examples
- Sensible defaults (TOP_LEFT for UI, CENTERED for math)
- Helper methods for coordinate conversion
- Examples demonstrating both systems

### Risk 3: Role Integration
**Concern:** Perl's class/role integration is limited

**Mitigation:**
- Document roles as "interface contracts"
- Provide trait checking utilities if needed
- Consider duck-typing approach
- Don't force role usage

### Risk 4: Terminal Compatibility
**Concern:** Not all terminals support 24-bit color or Unicode

**Mitigation:**
- Document terminal requirements
- Add capability detection utilities
- Provide fallback options (if feasible)
- Test on common terminals (iTerm2, Terminal.app, xterm)

---

## Success Metrics

### Phase 1 Complete
- [ ] All core classes ported
- [ ] tty::ansi integration working
- [ ] Basic shader rendering produces output
- [ ] Tests passing

### Phase 2 Complete
- [ ] Sprites working with Matrix storage
- [ ] All transformations functional
- [ ] Sprite rendering integrated

### Phase 3 Complete
- [ ] Input handling working
- [ ] Functional callbacks implemented
- [ ] Interactive examples running

### Phase 4 Complete
- [ ] Layout primitives available
- [ ] Basic widgets functional
- [ ] Performance acceptable

### Phase 5 Complete
- [ ] All examples ported
- [ ] Documentation comprehensive
- [ ] Ready for public use

### Overall Success
- [ ] Can build complete TUI applications using tty::graphics
- [ ] Integration with other grey::static features works smoothly
- [ ] Code quality matches grey::static standards
- [ ] Performance is acceptable for typical use cases
- [ ] Documentation enables new users to get started quickly

---

## Timeline and Status

| Phase | Status | Start Date | Completion Date | Notes |
|-------|--------|------------|-----------------|-------|
| Phase 1 | **COMPLETED** | 2025-12-11 | 2025-12-11 | All core classes ported, all tests passing |
| Phase 2 | Not Started | - | - | - |
| Phase 3 | Not Started | - | - | - |
| Phase 4 | Not Started | - | - | - |
| Phase 5 | Not Started | - | - | - |

---

## Notes and Decisions Log

### 2025-12-11: Project Initiated
- Completed deep dive analysis of both codebases
- Confirmed tty::graphics is the right integration point
- Decision: Use separate R/G/B matrices for sprites
- Decision: Refactor all ANSI codes to use tty::ansi
- Starting with Phase 1 implementation

### 2025-12-11: Phase 1 Completed ✓
- Successfully ported all core classes:
  - Graphics::Point - 2D coordinates
  - Graphics::Color - RGB color representation
  - Graphics::Shader - Core rendering engine
  - Graphics::Tools::Shaders - Utility functions (fract, distance, smoothstep, mix, etc.)
- All ANSI escape codes refactored to use ANSI::Screen, ANSI::Color, ANSI::Cursor
- Created comprehensive test suite (4 test files, 25 tests total)
- All tests passing successfully
- Fixed issues:
  - Added `use utf8;` for Unicode character support (▀)
  - Fixed `fract()` to use `floor()` instead of `int()` for correct negative number handling
  - Fixed ANSI function access by loading ANSI modules directly in Shader.pm
- Integration complete: Can now use `use grey::static qw[ tty::graphics ];`

---

## References

- Philo source: `/Users/stevan/Projects/perl/Philo`
- grey::static: `/Users/stevan/Projects/perl/p5-grey-static`
- Integration analysis: Initial conversation (2025-12-11)
- Related features: `tty::ansi`, `datatypes::numeric`, `functional`, `stream`
