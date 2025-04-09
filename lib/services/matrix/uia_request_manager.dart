import 'dart:math';

import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

import './matrix_service.dart';

extension UiaRequestManager on MatrixService {
  static final logger = Logger("UiaRequestManager");

  Future<void> uiaRequestHandler(UiaRequest request) async {
    try {
      if (request.state != UiaRequestState.waitForUser ||
          request.nextStages.isEmpty) {
        logger.fine("Uia Request Stage: ${request.state}");
        return;
      }

      final stage = request.nextStages.first;
      logger.fine("Uia Request Stage: $stage");
      switch (stage) {
        case AuthenticationTypes.password:
          final String? input =
              cachedPassword ??
              "DUMMY"; // TODO: replace with text input dialog which takes in the password
          if (input == null || input.isEmpty) {
            return request.cancel();
          }
          return request.completeStage(
            AuthenticationPassword(
              session: request.session,
              password: input,
              identifier: AuthenticationUserIdentifier(user: client.userID!),
            ),
          );
        case AuthenticationTypes.emailIdentity:
          if (currentThreepidCreds == null) {
            return request.cancel(
              UiaException(
                "This server needs to validate your email address for registration.",
              ),
            );
          }
          final auth = AuthenticationThreePidCreds(
            session: request.session,
            type: AuthenticationTypes.emailIdentity,
            threepidCreds: ThreepidCreds(
              sid: currentThreepidCreds!.sid,
              clientSecret: currentClientSecret,
            ),
          );
          //! TEMPORARY LOGIC
          if (Random().nextInt(100) % 2 == 0) {
            // TODO: replace with showOkCancelAlertDialog
            return request.completeStage(auth);
          }
          return request.cancel();
        case AuthenticationTypes.dummy:
          return request.completeStage(
            AuthenticationData(
              type: AuthenticationTypes.dummy,
              session: request.session,
            ),
          );
        default:
          final url = Uri.parse(
            '${client.homeserver}/_matrix/client/r0/auth/$stage/fallback/web?session=${request.session}',
          );
          launchUrlString(url.toString());
          //! TEMPORARY LOGIC
          if (Random().nextInt(100) % 2 == 0) {
            // TODO: replace with showOkCancelAlertDialog
            return request.completeStage(
              AuthenticationData(session: request.session),
            );
          } else {
            return request.cancel();
          }
      }
    } catch (e, s) {
      logger.severe('Error while background UIA', e, s);
      return request.cancel(e is Exception ? e : Exception(e));
    }
  }
}

class UiaException implements Exception {
  final String reason;

  UiaException(this.reason);

  @override
  String toString() => reason;
}
