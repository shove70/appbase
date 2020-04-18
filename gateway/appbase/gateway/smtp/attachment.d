module appbase.gateway.smtp.attachment;

import std.base64 : Base64;
import std.conv : to;

/**
  Implements mail message attachment.
 */
struct SmtpAttachment
{
    string filename;
    ubyte[] bytes;
    string cid;

    /++
      Returns plain base64 represenation of the attachment.
      The representaiton is ready to be injected into the formatted
      SMTP message.
     +/
    string toString(in string boundary) const {
        const string crlf = "\r\n";
        return "Content-Type: application/octet-stream" ~ crlf
        	~ ((cid !is null) ? "Content-ID: <" ~ cid ~ ">" : "") ~ crlf
          ~ "Content-Transfer-Encoding: base64" ~ crlf
          ~ "Content-Disposition: attachment; filename=\"" ~ filename ~ "\"" ~ crlf ~ crlf
          ~ to!string(Base64.encode(bytes)) ~ crlf
          ~ "--" ~ boundary ~ crlf;
    }
}
