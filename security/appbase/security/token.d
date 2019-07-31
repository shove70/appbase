module appbase.security.token;

import core.thread;

import std.bitmanip;
import std.exception : enforce;
import std.datetime;
import std.concurrency;
import std.base64;

import crypto.rsa;

import appbase.utils.utility;

class Token
{
    static ubyte[] generate(ulong userId, RSAKeyInfo publicKey)
    {
        ubyte[] token = new ubyte[ulong.sizeof + long.sizeof];
        token.write!ulong(userId, 0);
        long ticks = currTimeTick();
        token.write!long(ticks, ulong.sizeof);
        token ~= strToByte_hex(MD5(token)[0 .. 4]);
        token = RSA.encrypt(publicKey, token);

        insertCache(userId, token, ticks);

        return token;
    }

    static bool check(ulong userId, string token, RSAKeyInfo privateKey, const int tokenExpire)
    {
        scope(failure) { return false; }

        if (!cleanTaskRunning)
        {
            synchronized(Token.classinfo)
            {
                if (!cleanTaskRunning)
                {
                    spawn(&cleanTask, tokenExpire);
                    cleanTaskRunning = true;
                }
            }
        }

        ubyte[] _token = Base64.decode(token);

        if ((userId in pool) && (pool[userId].token == _token))
        {
            return true;
        }

        ubyte[] data = RSA.decrypt(privateKey, _token);

        if (data.length < ulong.sizeof + long.sizeof + 2)
        {
            return false;
        }

        if (strToByte_hex(MD5(data[0 .. $ - 2])[0 .. 4]) != data[$ - 2 .. $])
        {
            return false;
        }

        ulong _id = data.peek!ulong(0);
        if (_id != userId)
        {
            return false;
        }

        long ticks = data.peek!long(ulong.sizeof);
        if ((Clock.currTime() - currTimeFromTick(ticks)).total!"minutes" > tokenExpire)
        {
            return false;
        }

        insertCache(userId, _token, ticks);

        return true;
    }

    static string getTokenInPool(ulong userId)
    {
        if (userId !in pool)
        {
            return string.init;
        }

        return Base64.encode(pool[userId].token);
    }

private:

    static void insertCache(ulong userId, in ubyte[] token, long ticks)
    {
        CacheTokenData cache;
        cache.token = token.dup;
        cache.ticks = ticks;
        pool[userId] = cache;
    }

package:

    __gshared static CacheTokenData[ulong] pool;
    __gshared static bool cleanTaskRunning = false;
}

private:

struct CacheTokenData
{
    ubyte[] token;
    long ticks;
}

void cleanTask(const int tokenExpire)
{
    while (true)
    {
        Thread.sleep(1.hours);

        synchronized(Token.classinfo)
        {
            foreach(userId, data; Token.pool)
            {
                if ((Clock.currTime() - currTimeFromTick(data.ticks)).total!"minutes" > tokenExpire)
                {
                    Token.pool.remove(userId);
                }
            }
        }
    }
}
