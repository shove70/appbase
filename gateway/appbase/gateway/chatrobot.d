module appbase.gateway.chatrobot;

import std.net.curl : HTTP;
import std.typecons : No;

/// Send notify to WeCom
string sendToWeCom(const string key, const string message)
{
    const string url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=";

    auto http = HTTP(url ~ key);
    http.addRequestHeader("Content-Type", "application/json");
    string response;
    http.onReceive = (ubyte[] data) { response = cast(string) data; return data.length; };
    http.postData = `{"msgtype":"markdown","markdown":{"content":"` ~ message ~ `"}}`;
    http.perform(No.throwOnError);

    return response;
}

/// Send notify to Dingding
string sendToDingding(const string key, const string message)
{
    const string url = "https://oapi.dingtalk.com/robot/send?access_token=";

    auto http = HTTP(url ~ key);
    http.addRequestHeader("Content-Type", "application/json");
    string response;
    http.onReceive = (ubyte[] data) { response = cast(string) data; return data.length; };
    http.postData = `{"msgtype":"markdown","markdown":{"title":"Notify","text":"` ~ message ~ `"}}`;
    http.perform(No.throwOnError);

    return response;
}
