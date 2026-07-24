/// Public API of the auth feature. Import this barrel from `app/` and the
/// router — never reach into the feature's internal files (app-architecture §26).
library;

export 'domain/entities/user.dart';
export 'domain/entities/user_role.dart';
export 'presentation/cubit/auth_cubit.dart';
export 'presentation/cubit/password_reset_cubit.dart';
export 'presentation/pages/forgot_password_page.dart';
export 'presentation/pages/login_page.dart';
export 'presentation/pages/register_page.dart';
export 'presentation/pages/reset_password_page.dart';
