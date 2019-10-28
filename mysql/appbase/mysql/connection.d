module appbase.mysql.connection;

public import database.mysql;
import database.mysql.pool;

__gshared private ConnectionPool connectionPoolManager;

void initDBConnectionPool(string host, string user, string password, string database, ushort port = 3306,
    uint maxConnections = 10, uint initialConnections = 3, uint incrementalConnections = 3, uint waitSeconds = 5)
{
    connectionPoolManager = ConnectionPool.getInstance(
        host, user, password, database, port, maxConnections, initialConnections, incrementalConnections, waitSeconds);
}

void destroyDBConnectionPool()
{
    connectionPoolManager.destroy();
}

Connection getConnection(bool allowClientPreparedCache = false)
{
    Connection conn = connectionPoolManager.getConnection();
    if (conn is null)
    {
        throw new Exception("ConnectionPool.getConnection() fail.");
    }

    conn.allowClientPreparedCache = allowClientPreparedCache;
    return conn;
}

void releaseConnection(Connection conn)
{
    if (conn is null)
    {
        return;
    }

    connectionPoolManager.releaseConnection(conn);
}
