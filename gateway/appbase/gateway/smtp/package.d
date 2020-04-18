module appbase.gateway.smtp;

import std.net.curl : SMTP;
import std.typecons : Tuple;
import std.string : split;
import std.algorithm.iteration : each;

public import appbase.gateway.smtp.attachment;
public import appbase.gateway.smtp.message;

/++
    Send a email.
    recipients: a@xx.com;b@xx.com...
+/
Tuple!(int, string) sendMail(const string server,
    const string senderAccount, const string senderPassword, const string senderNicename,
    const string recipients, const string subject, const string content)
{
    Tuple!(int, string) result;

    auto client = SMTP("smtp://" ~ server);

    try
    {
        client.setAuthentication(senderAccount, senderPassword);
    }
    catch (Exception e)
    {
        client.shutdown();

        result[0] = -1;
        result[1] = e.msg;

        return result;
    }

    string[] addressees = recipients.split(";");
    Recipient[] _recipients;
    addressees.each!((a) => (_recipients ~= Recipient(a, "")));
    addressees.each!((ref a) => (a = "<" ~ a ~ ">"));
    client.mailTo = cast(const(char)[][])addressees;
    client.mailFrom = "<" ~ senderAccount ~ ">";

    auto message = SmtpMessage(
        Recipient(senderAccount, senderNicename),
        _recipients,
        subject,
        content,
        "",
    );
    client.message = message.toString();

    int trys;
    label_send: try
    {
        client.perform();
    }
    catch (Exception e)
    {
        if (++trys < 3)
        {
            goto label_send;
        }

        client.shutdown();

        result[0] = -2;
        result[1] = e.msg;

        return result;
    }

    return result;
}
