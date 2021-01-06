module appbase.listener;

import core.thread;

import std.socket;
import std.file;
import std.path;
import std.exception;
import std.parallelism : totalCPUs;

import async;

import appbase.utils.log;

alias RequestCallback = void function(TcpClient, const scope ubyte[]);

private __gshared ushort             _protocolMagic;
private __gshared RequestCallback    _request;
private __gshared OnSendCompleted    _onSendCompleted;

private __gshared ThreadPool         _businessPool;

deprecated("Will be removed in the next release.")
void startServer(const ushort port, const int businessThreads, const ushort protocolMagic,
    RequestCallback onRequest, OnSendCompleted onSendCompleted)
{
    startServer(port, protocolMagic, onRequest, onSendCompleted, businessThreads, 0);
}

void startServer(const ushort port, const ushort protocolMagic,
    RequestCallback onRequest, OnSendCompleted onSendCompleted, const int businessThreads = 0, const int workerThreads = 0)
{
    startServer("0.0.0.0", port, protocolMagic, onRequest, onSendCompleted, businessThreads, workerThreads);
}

void startServer(const string host, const ushort port, const ushort protocolMagic,
    RequestCallback onRequest, OnSendCompleted onSendCompleted, const int businessThreads = 0, const int workerThreads = 0)
{
    _businessPool    = new ThreadPool((businessThreads < 1) ? (totalCPUs * 2 + 2) : businessThreads);

    _protocolMagic   = protocolMagic;
    _request         = onRequest;
    _onSendCompleted = onSendCompleted;

    TcpListener listener = new TcpListener();
    listener.bind(new InternetAddress(host, port));
    listener.listen(1024);

    Codec codec = new Codec(CodecType.SizeGuide, protocolMagic);
    EventLoop loop = new EventLoop(listener, &onConnected, &onDisConnected, &onReceive, _onSendCompleted, &onSocketError, codec, workerThreads);
    loop.run();
}

private:

void onConnected(TcpClient client) nothrow @trusted
{
    // collectException({
    //     writeln("New connection: ", client.remoteAddress().toString());
    // }());
}

void onDisConnected(const int fd, string remoteAddress) nothrow @trusted
{
    // collectException({
    // }());
}

void onReceive(TcpClient client, const scope ubyte[] data) nothrow @trusted
{
    collectException({
        _businessPool.run!_request(client, data);
    }());
}

void onSocketError(const int fd, string remoteAddress, string msg) nothrow @trusted
{
    // collectException({
    //     logger.write(baseName(thisExePath) ~ " Socket Error: " ~ remoteAddress ~ ", " ~ msg);
    // }());
}
