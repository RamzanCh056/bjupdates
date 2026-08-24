import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      const String username = 'beatjerkyproduction@gmail.com';
      const String password = 'hiso uysq vfjp fglg';

      final smtpServer = gmail(username, password);

      final message = Message()
        ..from = Address(username, 'BeatJerky')
        ..recipients.add(to)
        ..subject = subject
        ..text = body
        ..html = body;

      final sendReport = await send(message, smtpServer);
      print('✅ Email sent successfully: $sendReport');
    } on MailerException catch (e) {
      print('❌ MailerException: ${e.message}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      rethrow;
    } catch (e) {
      print('❌ Error sending email: $e');
      rethrow;
    }
  }
}
