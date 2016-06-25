using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace NETIOCPSvr
{
    struct SendBufferPacket
    {
        public int Offset;
        public int Count;
    }

    /// <summary>
    /// 由于是异步发送，有可能接收到两个命令，写入了两次返回，发送需要等待上一次回调才发下一次的响应
    /// </summary>
    public class AsyncSendBufferManager
    {
        private DynamicBufferManager m_dynamicBufferManager;
        public DynamicBufferManager DynamicBufferManager { get { return m_dynamicBufferManager; } }
        private List<SendBufferPacket> m_sendBufferList;
        private SendBufferPacket m_sendBufferPacket;

        public AsyncSendBufferManager(int bufferSize)
        {
            m_dynamicBufferManager = new DynamicBufferManager(bufferSize);
            m_sendBufferList = new List<SendBufferPacket>();
            m_sendBufferPacket.Offset = 0;
            m_sendBufferPacket.Count = 0;
        }

        public void StartPacket()
        {
            m_sendBufferPacket.Offset = m_dynamicBufferManager.DataCount;
            m_sendBufferPacket.Count = 0;
        }

        public void EndPacket()
        {
            m_sendBufferPacket.Count = m_dynamicBufferManager.DataCount - m_sendBufferPacket.Offset;
            m_sendBufferList.Add(m_sendBufferPacket);
        }

        public bool GetFirstPacket(ref int offset, ref int count)
        {
            if (m_sendBufferList.Count <= 0)
                return false;
            offset = 0;//m_sendBufferList[0].Offset;清除了第一个包后，后续的包往前移，因此Offset都为0
            count = m_sendBufferList[0].Count;
            return true;
        }

        public bool ClearFirstPacket()
        {
            if (m_sendBufferList.Count <= 0)
                return false;
            int count = m_sendBufferList[0].Count;
            m_dynamicBufferManager.Clear(count);
            m_sendBufferList.RemoveAt(0);
            return true;
        }

        public void ClearPacket()
        {
            m_sendBufferList.Clear();
            m_dynamicBufferManager.Clear(m_dynamicBufferManager.DataCount);
        }
    }
}
