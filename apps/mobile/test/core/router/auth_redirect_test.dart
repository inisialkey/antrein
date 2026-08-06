import 'package:antrein/core/router/auth_redirect.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('logged out on a protected route → login', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: false,
          hasBusinessAccess: false,
          location: Routes.customerHome.path,
        ),
        Routes.login.path,
      );
    });

    test('logged out already on an auth route → no redirect', () {
      for (final path in authRoutePaths) {
        expect(
          resolveAuthRedirect(
            isLoggedIn: false,
            hasBusinessAccess: false,
            location: path,
          ),
          isNull,
          reason: '$path should be reachable while logged out',
        );
      }
    });

    test('logged-in customer on an auth route → customer home', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: true,
          hasBusinessAccess: false,
          location: Routes.login.path,
        ),
        Routes.customerHome.path,
      );
    });

    test('logged-in business user on an auth route → business home', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: true,
          hasBusinessAccess: true,
          location: Routes.login.path,
        ),
        Routes.businessHome.path,
      );
    });

    test('customer hitting the business shell → customer home', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: true,
          hasBusinessAccess: false,
          location: Routes.businessHome.path,
        ),
        Routes.customerHome.path,
      );
    });

    test('business user allowed on the business shell', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: true,
          hasBusinessAccess: true,
          location: Routes.businessHome.path,
        ),
        isNull,
      );
    });

    // Regression: businessDetail used to be `/business/:businessId`, so the
    // shell gate's prefix match bounced customers straight back to the home
    // list the moment they tapped a barbershop card.
    test('customer opening a public business detail → no redirect', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: true,
          hasBusinessAccess: false,
          location: Routes.businessDetail.path.replaceFirst(
            ':businessId',
            'biz_1',
          ),
        ),
        isNull,
      );
    });

    test('logged-in user on a normal route → no redirect', () {
      expect(
        resolveAuthRedirect(
          isLoggedIn: true,
          hasBusinessAccess: false,
          location: Routes.customerHome.path,
        ),
        isNull,
      );
    });
  });
}
