module appbase.gateway.sms;

import std.string;
import std.conv;
import std.base64;
import std.net.curl;
import std.uri;
import std.json;
import std.typecons : Tuple;
import std.xml;

import crypto.aes;
import appbase.utils;

struct Sms1
{
    /++
    The document of soap response:
    <?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    	<soap:Body>
    		<SendSMS_2Response xmlns="http://tempuri.org/">
    			<SendSMS_2Result>
    				<xs:schema id="NewDataSet" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
    					<xs:element name="NewDataSet" msdata:IsDataSet="true" msdata:UseCurrentLocale="true">
    						<xs:complexType>
    							<xs:choice minOccurs="0" maxOccurs="unbounded">
    								<xs:element name="Table1">
    									<xs:complexType>
    										<xs:sequence>
    											<xs:element name="Result" type="xs:long" minOccurs="0" />
    											<xs:element name="Description" type="xs:string" minOccurs="0" />
    										</xs:sequence>
    									</xs:complexType>
    								</xs:element>
    							</xs:choice>
    						</xs:complexType>
    					</xs:element>
    				</xs:schema>
    				<diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">
    					<NewDataSet xmlns="">
    						<Table1 diffgr:id="Table11" msdata:rowOrder="0" diffgr:hasChanges="inserted">
    							<Result>-6</Result>
    							<Description>手机号码格式错误</Description>
    						</Table1>
    					</NewDataSet>
    				</diffgr:diffgram>
    			</SendSMS_2Result>
    		</SendSMS_2Response>
    	</soap:Body>
    </soap:Envelope>
    +/
    static Tuple!(int, string) send(const string gatewayUrl, const string account, const string key, const string mobile, const string content)
    {
        Tuple!(int, string) result;

        const string timeStamp = dateTimeToString(now);
        const string sign = MD5(account ~ timeStamp ~ content ~ mobile ~ timeStamp.replace("-", "").replace(":", "") ~ key);
        const string request = format(`<?xml version="1.0" encoding="utf-8"?>
            <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
              <soap12:Body>
                <SendSMS_2 xmlns="http://tempuri.org/">
                  <RegCode>%s</RegCode>
                  <TimeStamp>%s</TimeStamp>
                  <Sign>%s</Sign>
                  <Content>%s</Content>
                  <To>%s</To>
                  <SendTime>%s</SendTime>
                </SendSMS_2>
              </soap12:Body>
            </soap12:Envelope>`, account, timeStamp, sign, content, mobile, timeStamp.replace(" ", "T"));

        auto http = HTTP(gatewayUrl);
        http.setPostData(request, "application/soap+xml; charset=utf-8");
        string response;
        http.onReceive = (ubyte[] data) { response ~= cast(string)data; return data.length; };

        try
        {
            http.perform();
        }
        catch (Exception e)
        {
            result[0] = -1001;
            result[1] = e.msg;

            return result;
        }

        if (response.empty)
        {
            result[0] = -1002;
            result[1] = "Response empty.";

            return result;
        }

        DocumentParser xml;
        try
        {
            xml = new DocumentParser(response);
        }
        catch (Exception e)
        {
            result[0] = -1003;
            result[1] = e.msg;

            return result;
        }

        string ret_code, ret_description;
        xml.onStartTag["Table1"] = (ElementParser xml)
        {
            xml.onEndTag["Result"]      = (in Element e) { ret_code        = e.text(); };
            xml.onEndTag["Description"] = (in Element e) { ret_description = e.text(); };
            xml.parse();
        };
        xml.parse();

        result[0] = as!int(ret_code, -1004);
        result[1] = ret_description;

        return result;
    }
}

// for Sms1
unittest
{
    import std.stdio : writeln;
    writeln(Sms1.send("https://....", "account", "key", "135xxxxxxxx", "content"));
}

struct Sms2
{
    static Tuple!(int, string) send(const string gatewayUrl, const string account, const string key, const string id, const string mobile, const string templateCode, const string templateParams, const string smsSign)
    {
        Tuple!(int, string) result;

        string url = buildRequestUrl(gatewayUrl, account, key, id, mobile, templateCode, templateParams, smsSign);

        string response;
        try
        {
            response = cast(string)get(url);
        }
        catch (Exception e)
        {
            result[0] = -2;
            result[1] = e.msg;

            return result;
        }

        JSONValue json;
        try
        {
            json = parseJSON(response);
        }
        catch (Exception e)
        {
            result[0] = -3;
            result[1] = e.msg;

            return result;
        }

        string res_code, res_message, res_timestamp, res_body, res_sign;
        try
        {
            res_code = json["code"].str;
            res_message = decodeComponent!dchar(json["message"].str.to!dstring).to!string;
            res_timestamp = decodeComponent(json["timestamp"].str);
            res_body = decodeComponent(json["body"].str);
            res_sign = json["sign"].str;
        }
        catch (Exception e)
        {
            result[0] = -4;
            result[1] = e.msg;

            return result;
        }

        if (!checkResponseSign(key, res_code, res_message, res_body, res_timestamp, res_sign))
        {
            result[0] = -5;
            result[1] = "Received data signature error";

            return result;
        }

        if (res_code != "0")
        {
            result[0] = -6;
            result[1] = res_message ~ ", code: " ~ res_code;

            return result;
        }

        // res_body = decryptAES(res_body);
        // JSONValue json_body;

        // try
        // {
        //     json_body = parseJSON(res_body);
        // }
        // catch (Exception e)
        // {
        //     result[0] = -7;
        //     result[1] = e.msg;

        //     return result;
        // }

        result[0] = 0;
        return result;
    }

private:

    static ubyte[] AES_IV = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    static string encryptAES(const string key, const string data)
    {
        char[] bkey = cast(char[])strToByte_hex(MD5(key));
        return Base64.encode(AESUtils.encrypt!AES128(cast(ubyte[])data, bkey, AES_IV, PaddingMode.PKCS5));
    }

    static string decryptAES(const string key, const string data)
    {
        char[] bkey = cast(char[])strToByte_hex(MD5(key));
        return cast(string)AESUtils.decrypt!AES128(Base64.decode(data), bkey, AES_IV, PaddingMode.PKCS5);
    }

    static string buildRequestUrl(const string gatewayUrl, const string account, const string key, const string id, const string mobile, const string templateCode, const string templateParams, const string smsSign)
    {
        string content = encryptAES(key,
            format(`{ "action":"SendSms", "smsid":"%s", "phone":"%s", "signName":"%s", "templateCode":"%s", "templateParams":"{%s}", "sendTime":"", "version":"1.0.0" }`,
                id, mobile, smsSign, templateCode, templateParams));
        string timestamp = dateTimeToString(now);
        string sign = MD5(format("apiAccount=%s&body=%s&timestamp=%s&apikey=%s", account, content, timestamp, key));

        return format("%s?apiAccount=%s&body=%s&timestamp=%s&sign=%s", gatewayUrl, account, encodeComponent(content), encodeComponent(timestamp), sign);
    }

    static bool checkResponseSign(const string key, const string code, const string message, const string content, const string timestamp, const string sign)
    {
        string local_sign = MD5(format("body=%s&code=%s&message=%s&timestamp=%s&apikey=%s", content, code, message, timestamp, key));
        return (local_sign == sign.toUpper());
    }
}

// for Sms2
unittest
{
    import std.stdio : writeln;
    writeln(Sms2.send("ipaddress", "account", "key", "1", "135xxxxxxxx", "TP001", "a,b", "【签名】"));
}
