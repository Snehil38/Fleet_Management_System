////
////  AuthLoginDriver.swift
////  Team08_FMS
////
////  Created by Ravi Tiwari on 19/03/25.
////
//
//import Foundation
//import SwiftSMTP
//
//// SMTP Server Configuration
//let smtp = SMTP(
//    hostname: "smtp.gmail.com", // Your SMTP server
//    email: "your-email@gmail.com",
//    password: "your-email-password"
//)
//
//// Sender and Receiver
//let sender = Mail.User(name: "Your Name", email: "your-email@gmail.com")
//let recipient = Mail.User(name: "Recipient Name", email: "recipient@example.com")
//
//// Create Email
//let mail = Mail(
//    from: sender,
//    to: [recipient],
//    subject: "Test Email from Swift!",
//    text: "Hello, this is a test email sent using SwiftSMTP."
//)
//
//// Send Email
//smtp.send(mail) { result in
//    switch result {
//    case .success:
//        print("Email sent successfully!")
//    case .failure(let error):
//        print("Failed to send email: \(error)")
//    }
//}
import Foundation
import SwiftSMTP

class EmailService {
    private let smtp: SMTP

    init() {
        // Configure your SMTP server settings
        smtp = SMTP(
            hostname: "smtp.gmail.com", // e.g., smtp.gmail.com
            email: "rt9593878@gmail.com", password: "ibda bytr uomg scxw" // Your email address
            //password: "1234567890abcdef”
        )
    }

    func sendEmail(to recipient: String, subject: String, body: String) async -> Bool {
        let from = Mail.User(name: "Ravi Tiwari", email: "rt9593878@gmail.com")
        let to = Mail.User(name: "Recipient Name", email: recipient)

        let mail = Mail(
            from: from,
            to: [to],
            subject: subject,
            text: body
        )

        do {
            try await smtp.send(mail)
            print("Email sent successfully to \(recipient)")
            return true
        } catch {
            print("Failed to send email: \(error.localizedDescription)")
            return false
        }
    }
}
