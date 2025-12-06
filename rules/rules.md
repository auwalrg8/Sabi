# Flutter Development Guidelines & Standards

## Core Development Principles

### 1. Widget Architecture Rules

- **NEVER create methods or functions that return widgets**
- All UI components must be implemented as proper StatelessWidget or StatefulWidget classes
- Use composition over widget-returning methods for better performance and maintainability

### 2. UI/UX Standards

#### Design Principles

- **Intuitive and Aesthetic**: Focus on clean, modern, and user-friendly interfaces
- **Professional and Enterprise Standard**: Maintain high-quality, business-grade design patterns
- **Consistent Visual Language**: Use standardized spacing, typography, and component patterns

#### Required Packages & Libraries

- **flutter_animate**: For smooth animations and transitions
- **iconsax**: Primary icon library for consistent iconography
- **font_awesome_flutter**: Secondary icon library for specialized icons
- **google_fonts**: Typography system using Google Fonts

#### Color System

- **ALWAYS use Theme.of(context) for colors**
- Never hardcode color values
- Utilize Material 3 color scheme:

  ```dart
  Theme.of(context).colorScheme.primary
  Theme.of(context).colorScheme.secondary
  Theme.of(context).colorScheme.surface
  Theme.of(context).colorScheme.onSurface
  // etc.
  ```

### 3. Animation Guidelines

- Use flutter_animate for all animations
- Implement staggered animations for list items and cards
- Apply entrance animations (fadeIn, slideY, scale) with appropriate delays
- Maintain consistent animation durations (200ms-800ms range)

### 4. Accessibility & Performance

- Ensure proper semantic labels for screen readers
- Optimize widget rebuilds using const constructors
- Implement lazy loading for large datasets
- Use appropriate image optimization and caching

### 7. Testing Standards

- Write unit tests for business logic
- Implement widget tests for UI components
- Use integration tests for critical user flows
- Maintain minimum 80% code coverage

### 8. Widgets and Utilities or Helpers

- Widgets and components should be always from the zoni_ui package; if it does not exist create it in the widgets folder and organized in directors
- All widgets should be from the zoni_ui packag, if it does not exist create it in the widgets folder and organized in directors
- All Helper methods should be in the helpers directory
- All Constants should be in the constants
- All Storage Keys should be in the StorageKeys with static calls
- All App Sizes should be from zoni_ui if not exists then create it in the constants
- All enums, extensions etc should be in the data folder inside their respective directories
- For dialogs also use zoni_ui if not exists then create then create ZoniDialog class if it does not exists create it using wolt modal sheet with static methods such as info, confirm, error,warn, danger etc. Also Create ZoniLoader for loadings animation using the wolt modal.
- For toasts create a ZoniToast class with static methods for success, error, info, warn, danger etc. using another_flushbar <https://pub.dev/packages/another_flushbar>
- For all logs, Get.log or prints use the loggingservice
- For all charts create uisng fl_chart <https://pub.dev/packages/fl_chart>

## Implementation Checklist

Before submitting any Flutter code, ensure:

- [ ] No widget-returning methods used
- [ ] SiteTemplate structure implemented with separate responsive views
- [ ] Theme.of(context) used for all colors
- [ ] flutter_animate implemented for animations
- [ ] Iconsax/FontAwesome icons used consistently
- [ ] Professional, enterprise-grade UI design
- [ ] Proper error handling and loading states
- [ ] Accessibility considerations implemented
- [ ] Performance optimizations applied
