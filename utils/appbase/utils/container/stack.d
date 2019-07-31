    module appbase.utils.container.stack;

    import std.container.dlist;

    struct Stack(T)
    {
        @property bool empty() const
        {
            return _data.empty();
        }

        @property ref T front()
        {
            return _data.front();
        }

        @property ref T back()
        {
            return _data.back();
        }

        @property size_t length()
        {
            return _size;
        }

        void push(T value)
        {
            _data.insertBack(value);
            _size++;
        }

        T pop()
        {
            assert(!_data.empty(), "Queue is empty.");

            T value = _data.back();
            _data.removeBack();
            _size--;

            return value;
        }

        void clear()
        {
            _data.clear();
            _size = 0;
        }

    private:

        DList!T _data;
        size_t  _size = 0;
    }
    