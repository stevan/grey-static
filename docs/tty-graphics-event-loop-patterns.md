# Graphics Event Loop Integration Patterns

This document explores patterns for integrating `tty::graphics` with grey::static's other features to create interactive terminal applications with event loops.

## Overview

Terminal graphics applications typically require an event loop that:
1. Processes input (keyboard, mouse)
2. Updates application state
3. Renders graphics
4. Controls frame timing

grey::static provides several features that can work together to create elegant event loops:
- **tty::graphics** - Rendering and input capture
- **time::stream** - Frame timing and delta time
- **stream** - Lazy evaluation and composition
- **functional** - Consumer callbacks
- **concurrency::reactive** - Reactive event streams (Flow)

## Pattern 1: Polling Loop with Delta Time

**Best for:** Games, animations, real-time simulations

Uses `Time::of_delta()` to create a stream of delta times, polling input on each frame.

### Architecture

```perl
use grey::static qw[
    tty::graphics
    time::stream
    functional
    stream
];

# Game state
my $state = {
    x => 60,
    y => 30,
    velocity => { x => 0, y => 0 }
};

# Input handlers
my $keys = ArrowKeys(
    on_up    => Consumer->new(f => sub { $state->{velocity}{y} = -1 }),
    on_down  => Consumer->new(f => sub { $state->{velocity}{y} =  1 }),
    on_left  => Consumer->new(f => sub { $state->{velocity}{x} = -1 }),
    on_right => Consumer->new(f => sub { $state->{velocity}{x} =  1 }),
);

# Shader for rendering
my $shader = Shader(
    height => 60,
    width => 120,
    shader => sub ($p, $t) {
        my $d = distance($p->x - $state->{x}, $p->y - $state->{y});
        return $d < 5
            ? Color(r => 1, g => 0, b => 0)
            : Color(r => 0, g => 0, b => 0.1);
    }
);

# Event loop
$keys->turn_echo_off;
$shader->clear_screen;
$shader->hide_cursor;

Time->of_delta()
    ->peek(sub ($dt) {
        # 1. Process input
        $keys->capture_keypress;
    })
    ->peek(sub ($dt) {
        # 2. Update state
        $state->{x} += $state->{velocity}{x} * $dt * 50;
        $state->{y} += $state->{velocity}{y} * $dt * 50;

        # Friction
        $state->{velocity}{x} *= 0.9;
        $state->{velocity}{y} *= 0.9;
    })
    ->peek(sub ($dt) {
        # 3. Render
        $shader->draw(Time::HiRes::time());
    })
    ->sleep_for(0.016)  # Target ~60 FPS
    ->take(3600)        # Run for 60 seconds at 60 FPS
    ->for_each(Consumer->new(f => sub { }));

$keys->turn_echo_on;
$shader->show_cursor;
```

### Advantages
- Simple, clear game loop structure
- Predictable timing with delta time
- Easy to understand flow
- Built-in FPS control via `sleep_for()`

### Disadvantages
- Polling-based (uses CPU even when idle)
- Fixed to stream iteration model

## Pattern 2: State Machine with Consumers

**Best for:** Menu systems, turn-based games, state-driven UIs

Separates rendering and input handling into discrete states.

### Architecture

```perl
use grey::static qw[
    tty::graphics
    functional
    datatypes::util
];

# State machine
my $current_state = 'menu';
my $menu_selection = 0;

# State-specific input handlers
my %states = (
    menu => {
        render => sub {
            # Render menu
        },
        keys => ArrowKeys(
            on_up   => Consumer->new(f => sub { $menu_selection-- }),
            on_down => Consumer->new(f => sub { $menu_selection++ }),
            # Enter key transitions to game
        )
    },
    game => {
        render => sub {
            # Render game
        },
        keys => ArrowKeys(
            # Game controls
        )
    }
);

# Main loop
while (1) {
    my $state = $states{$current_state};
    $state->{keys}->capture_keypress;
    $state->{render}->();
    Time::HiRes::sleep(0.016);
}
```

### Advantages
- Clear separation of concerns
- Easy to add new states
- Can have different input bindings per state

### Disadvantages
- More boilerplate
- Manual loop management

## Pattern 3: Reactive Flow Integration

**Best for:** Event-driven applications, complex async coordination

Creates a reactive publisher that emits keyboard events.

### Architecture

```perl
use grey::static qw[
    tty::graphics
    concurrency::reactive
    functional
];

# Create a keypress publisher
class KeyPressPublisher :isa(Flow::Publisher) {
    field $keys;
    field $interval;  # Polling interval in seconds

    ADJUST {
        $keys = ArrowKeys(
            on_key => Consumer->new(f => sub ($event) {
                # Events will be emitted via subscriber
            })
        );
        $interval //= 0.016;  # Default 60 Hz
    }

    method subscribe ($subscriber) {
        $keys->turn_echo_off;

        # Polling loop
        while (1) {
            if (my $direction = $keys->capture_keypress) {
                $subscriber->on_next($direction);
            }
            Time::HiRes::sleep($interval);
        }
    }
}

# Usage
my $key_flow = Flow->from_publisher(KeyPressPublisher->new);

$key_flow
    ->map(Function->new(f => sub ($dir) {
        return { direction => $dir, timestamp => time };
    }))
    ->filter(Predicate->new(f => sub ($event) {
        # Filter out rapid repeats
        return $event->{timestamp} - $last_time > 0.1;
    }))
    ->subscribe(Flow::Subscriber->new(
        on_next => Consumer->new(f => sub ($event) {
            say "Key pressed: $event->{direction}";
        })
    ));
```

### Advantages
- Full reactive programming support
- Can compose with other Flow operations
- Natural async coordination

### Disadvantages
- More complex setup
- Polling loop hidden inside publisher
- Harder to integrate with rendering

## Pattern 4: Unified Stream Pipeline

**Best for:** Data processing, visualizations, animations without input

Combines time stream with functional transformations for pure animation.

### Architecture

```perl
use grey::static qw[
    tty::graphics
    time::stream
    stream
    functional
];

my $shader = Shader(
    height => 60,
    width => 120,
    coord_system => Shader->CENTERED,
    shader => sub ($p, $t) {
        my ($x, $y) = $p->xy;
        my $d = distance($x, $y);
        return Color(
            r => smoothstep(-1, 1, sin($d * 10 - $t * 3)),
            g => 0.5,
            b => 0.8
        );
    }
);

$shader->clear_screen;
$shader->hide_cursor;

Time->of_monotonic()
    ->map(Function->new(f => sub ($t) {
        # Transform time (e.g., slow down)
        return $t * 0.5;
    }))
    ->peek(sub ($t) {
        $shader->draw($t);
    })
    ->sleep_for(0.016)
    ->take(3600)
    ->for_each(Consumer->new(f => sub { }));

$shader->show_cursor;
```

### Advantages
- Pure functional pipeline
- No state management
- Beautiful composition
- Perfect for demos/visualizations

### Disadvantages
- No input handling
- Limited to passive animations

## Recommended Patterns by Use Case

| Use Case | Pattern | Key Features |
|----------|---------|--------------|
| **Games** | Pattern 1 (Polling Loop) | Delta time, input, physics, rendering |
| **Menus/UIs** | Pattern 2 (State Machine) | Discrete states, navigation |
| **Visualizations** | Pattern 4 (Unified Stream) | Pure animation, no input |
| **Complex Async** | Pattern 3 (Reactive Flow) | Event composition, async coordination |

## Advanced: Combining Patterns

Real applications often combine multiple patterns:

```perl
# Use Pattern 4 for background animation
my $background_animation = Time->of_monotonic()
    ->map(Function->new(f => sub ($t) { ... }))
    ->for_each(...);

# Use Pattern 1 for game loop
my $game_loop = Time->of_delta()
    ->peek(sub { poll_input() })
    ->peek(sub ($dt) { update_physics($dt) })
    ->peek(sub { render() })
    ->for_each(...);

# Use Pattern 2 for menu system
my $menu_state_machine = ...;
```

## Performance Considerations

### Frame Rate Control

```perl
# Option 1: sleep_for (simple)
Time->of_delta()
    ->sleep_for(0.016)  # ~60 FPS
    ->for_each(...);

# Option 2: Manual delta accumulation (precise)
my $target_dt = 0.016;
my $accumulator = 0;

Time->of_delta()
    ->peek(sub ($dt) {
        $accumulator += $dt;
        if ($accumulator >= $target_dt) {
            update_and_render();
            $accumulator -= $target_dt;
        }
    })
    ->for_each(...);
```

### Input Buffering

For responsive input, poll at higher frequency than rendering:

```perl
my $frame_time = 0;

Time->of_delta()
    ->peek(sub ($dt) {
        # Poll input at full speed
        $keys->capture_keypress;
        $frame_time += $dt;
    })
    ->peek(sub ($dt) {
        # Render at 60 FPS
        if ($frame_time >= 0.016) {
            render();
            $frame_time = 0;
        }
    })
    ->for_each(...);
```

## Future Enhancements

Potential additions to make event loops even more powerful:

1. **EventLoop class** - Higher-level abstraction combining patterns
2. **Async keyboard stream** - Non-polling keypress publisher
3. **Frame timing utilities** - Built-in FPS counter, frame skip logic
4. **Input replay** - Record and playback input sequences
5. **Multi-threaded rendering** - Render in background thread

## Example: Complete Game Loop

See `examples/graphics/interactive-sprite.pl` for a complete example combining:
- ArrowKeys for input
- Time::of_delta() for timing
- Sprite for graphics
- Shader for rendering
- State management with closures

## Conclusion

grey::static's composable features enable multiple event loop patterns, each suited to different use cases. The polling loop with delta time (Pattern 1) is recommended as the default for most interactive applications, while reactive flows (Pattern 3) excel at complex async coordination.

The key insight: **Use Stream operations to structure your event loop, Consumers for callbacks, and time::stream for timing.**
