module appbase.gateway.chatrobot;

import std.net.curl : HTTP;
import std.typecons : No;

/// Send notify to chat (DingDing, weCom)
private string sendToChat(string url)(const string key, const string message)
{
    auto http = HTTP(url ~ key);
    http.addRequestHeader("Content-Type", "application/json");
    string response;
    http.onReceive = (ubyte[] data) { response = cast(string) data; return data.length; };
    http.postData = `{"msgtype":"markdown","markdown":{"content":"` ~ message ~ `"}}`;
    http.perform(No.throwOnError);

    return response;
}

/// ditto
string sendToDingding(const string key, const string message)
{
    return sendToChat!"https://oapi.dingtalk.com/robot/send?access_token="(key, message);
}

/// ditto
string sendToWeCom(const string key, const string message)
{
    return sendToChat!"https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key="(key, message);
}
