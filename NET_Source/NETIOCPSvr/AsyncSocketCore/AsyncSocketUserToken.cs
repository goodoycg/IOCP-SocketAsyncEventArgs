using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;

namespace NETIOCPSvr
{
    /// <summary>
    /// 用于SocketAsyncEventArgs绑定，保存每个Socket服务对象
    /// </summary>
    public class AsyncSocketUserToken
    {
        protected SocketAsyncEventArgs m_receiveEventArgs;
        /// <summary>
        /// 接收异步事件
        /// </summary>
        public SocketAsyncEventArgs ReceiveEventArgs { get { return m_receiveEventArgs; } set { m_receiveEventArgs = value; } }
        protected byte[] m_asyncReceiveBuffer;        
        protected SocketAsyncEventArgs m_sendEventArgs;
        /// <summary>
        /// 发送异步事件
        /// </summary>
        public SocketAsyncEventArgs SendEventArgs { get { return m_sendEventArgs; } set { m_sendEventArgs = value; } }

        protected DynamicBufferManager m_receiveBuffer;
        /// <summary>
        /// 接收数据缓冲区
        /// </summary>
        public DynamicBufferManager ReceiveBuffer { get { return m_receiveBuffer; } set { m_receiveBuffer = value; } }
        protected AsyncSendBufferManager m_sendBuffer;
        /// <summary>
        /// 发送数据缓冲区
        /// </summary>
        public AsyncSendBufferManager SendBuffer { get { return m_sendBuffer; } set { m_sendBuffer = value; } }

        protected AsyncSocketInvokeElement m_asyncSocketInvokeElement; //协议对象
        /// <summary>
        /// 协议逻辑调用对象
        /// 用于协议调用的基类，主要实现分包，并发发送的包加到发送列表中，发送完成回调时继续发送下一个包
        /// </summary>
        public AsyncSocketInvokeElement AsyncSocketInvokeElement { get { return m_asyncSocketInvokeElement; } set { m_asyncSocketInvokeElement = value; } }

        protected Socket m_connectSocket;
        /// <summary>
        /// 连接的Socket对象
        /// </summary>
        public Socket ConnectSocket
        {
            get
            {
                return m_connectSocket;
            }
            set
            {
                m_connectSocket = value;
                if (m_connectSocket == null) //清理缓存
                {
                    if (m_asyncSocketInvokeElement != null)
                        m_asyncSocketInvokeElement.Close();
                    m_receiveBuffer.Clear(m_receiveBuffer.DataCount);
                    m_sendBuffer.ClearPacket();
                }
                m_asyncSocketInvokeElement = null;                
                m_receiveEventArgs.AcceptSocket = m_connectSocket;
                m_sendEventArgs.AcceptSocket = m_connectSocket;
            }
        }

        protected DateTime m_ConnectDateTime;
        public DateTime ConnectDateTime { get { return m_ConnectDateTime; } set { m_ConnectDateTime = value; } }
        protected DateTime m_ActiveDateTime;
        public DateTime ActiveDateTime { get { return m_ActiveDateTime; } set { m_ActiveDateTime = value; } }

        public AsyncSocketUserToken(int asyncReceiveBufferSize)
        {
            m_connectSocket = null;
            m_asyncSocketInvokeElement = null;
            m_receiveEventArgs = new SocketAsyncEventArgs();
            m_receiveEventArgs.UserToken = this;
            m_asyncReceiveBuffer = new byte[asyncReceiveBufferSize];
            m_receiveEventArgs.SetBuffer(m_asyncReceiveBuffer, 0, m_asyncReceiveBuffer.Length);
            m_sendEventArgs = new SocketAsyncEventArgs();
            m_sendEventArgs.UserToken = this;
            m_receiveBuffer = new DynamicBufferManager(ProtocolConst.InitBufferSize);
            m_sendBuffer = new AsyncSendBufferManager(ProtocolConst.InitBufferSize); ;
        }
    }
}
