using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace NETIOCPSvr
{
    /// <summary>
    /// 固定缓存设计需要建立一个列表进行，并在初始化的时候加入到列表中
    /// </summary>
    public class AsyncSocketUserTokenPool
    {
        private Stack<AsyncSocketUserToken> m_pool;

        public AsyncSocketUserTokenPool(int capacity)
        {
            m_pool = new Stack<AsyncSocketUserToken>(capacity);
        }
        /// <summary>
        /// 
        /// </summary>
        /// <param name="item"></param>
        public void Push(AsyncSocketUserToken item)
        {
            if (item == null)
            {
                throw new ArgumentException("Items added to a AsyncSocketUserToken cannot be null");
            }
            lock (m_pool)
            {//对m_asyncSocketUserTokenPool和m_asyncSocketUserTokenList进行处理的时候都有加锁
                m_pool.Push(item);
            }
        }
        /// <summary>
        /// 
        /// </summary>
        /// <returns></returns>
        public AsyncSocketUserToken Pop()
        {
            lock (m_pool)
            {//对m_asyncSocketUserTokenPool和m_asyncSocketUserTokenList进行处理的时候都有加锁
                return m_pool.Pop();
            }
        }

        public int Count
        {
            get { return m_pool.Count; }
        }
    }

    public class AsyncSocketUserTokenList : Object
    {
        private List<AsyncSocketUserToken> m_list;

        public AsyncSocketUserTokenList()
        {
            m_list = new List<AsyncSocketUserToken>();
        }

        public void Add(AsyncSocketUserToken userToken)
        {
            lock(m_list)
            {
                m_list.Add(userToken);
            }
        }

        public void Remove(AsyncSocketUserToken userToken)
        {
            lock (m_list)
            {
                m_list.Remove(userToken);
            }
        }

        public void CopyList(ref AsyncSocketUserToken[] array)
        {
            lock (m_list)
            {
                array = new AsyncSocketUserToken[m_list.Count];
                m_list.CopyTo(array);
            }
        }
    }
}
