module appbase.listener;

import core.thread;
import core.sync.mutex;

import std.bitmanip;
import std.socket;
import std.file;
import std.path;
import std.exception;

import async;
import async.container;

import appbase.utils.log;

alias RequestCallback = void function(TcpClient, in ubyte[]);

private __gshared ushort             _protocolMagic;
private __gshared RequestCallback    _request;
private __gshared OnSendCompleted    _onSendCompleted;

private __gshared ByteBuffer[int]    _queue;
private __gshared Mutex              _lock;

private __gshared ThreadPool         _businessPool;

void startServer(const ushort port, const int workThreads, const ushort protocolMagic,
    RequestCallback onRequest, OnSendCompleted onSendCompleted)
{
    _lock            = new Mutex();
    _businessPool    = new ThreadPool(workThreads);

    _protocolMagic   = protocolMagic;
    _request         = onRequest;
    _onSendCompleted = onSendCompleted;

    TcpListener listener = new TcpListener();
    listener.bind(new InternetAddress("0.0.0.0", port));
    listener.listen(1024);

    EventLoop loop = new EventLoop(listener, &onConnected, &onDisConnected, &onReceive, _onSendCompleted, &onSocketError);
    loop.run();
}

private:

void onConnected(TcpClient client) nothrow @trusted
{
    collectException({
        synchronized(_lock) _queue[client.fd] = ByteBuffer();
        //writeln("New connection: ", client.remoteAddress().toString());
    }());
}

void onDisConnected(int fd, string remoteAddress) nothrow @trusted
{
    collectException({
        synchronized(_lock) _queue.remove(fd);
    }());
}

void onReceive(TcpClient client, in ubyte[] data) nothrow @trusted
{
    collectException({
        ubyte[] buffer;

        synchronized(_lock)
        {
            if (client.fd !in _queue)
            {
                logger.write(baseName(thisExePath) ~ " Socket Error: " ~ client.remoteAddress.toString() ~ ", queue key not exists!");
                return;
            }

            _queue[client.fd] ~= data;

            size_t len = findCompleteMessage(client, _queue[client.fd]);
            if (len == 0)
            {
                return;
            }

            buffer = _queue[client.fd][0 .. len];
            _queue[client.fd].popFront(len);
        }

        _businessPool.run!_request(client, buffer);
    }());
}

void onSocketError(int fd, string remoteAddress, string msg) nothrow @trusted
{
    // collectException({
    //     logger.write(baseName(thisExePath) ~ " Socket Error: " ~ remoteAddress ~ ", " ~ msg);
    // }());
}

size_t findCompleteMessage(TcpClient client, ref ByteBuffer data)
{
    if (data.length < (ushort.sizeof + int.sizeof))
    {
        return 0;
    }

    ubyte[] head = data[0 .. ushort.sizeof + int.sizeof];

    if (head.peek!ushort(0) != _protocolMagic)
    {
        string remoteAddress = client.remoteAddress().toString();
        client.forceClose();
        //logger.write(baseName(thisExePath) ~ " Socket Error: " ~ remoteAddress ~ ", An unusual message data!");

        return 0;
    }

    size_t len = head.peek!int(ushort.sizeof);

    if (data.length < (len + (ushort.sizeof + int.sizeof)))
    {
        return 0;
    }

    return len + (ushort.sizeof + int.sizeof);
}
