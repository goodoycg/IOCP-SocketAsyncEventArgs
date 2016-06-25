using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net.Sockets;
using NETIOCPSvr;

namespace NETUploadClient.SyncSocketCore
{
    public class SyncSocketInvokeElement
    {
        protected TcpClient m_tcpClient;
        protected string m_host;
        protected int m_port;
        protected ProtocolFlag m_protocolFlag;
        protected int SocketTimeOutMS { get {return m_tcpClient.SendTimeout; } set { m_tcpClient.SendTimeout = value; m_tcpClient.ReceiveTimeout = value; } }
        private bool m_netByteOrder;
        public bool NetByteOrder { get { return m_netByteOrder; } set { m_netByteOrder = value; } } //长度是否使用网络字节顺序
        protected OutgoingDataAssembler m_outgoingDataAssembler; //协议组装器，用来组装往外发送的命令
        protected DynamicBufferManager m_recvBuffer; //接收数据的缓存
        protected IncomingDataParser m_incomingDataParser; //收到数据的解析器，用于解析返回的内容
        protected DynamicBufferManager m_sendBuffer; //发送数据的缓存，统一写到内存中，调用一次发送

        public SyncSocketInvokeElement()
        {
            m_tcpClient = new TcpClient();
            m_tcpClient.Client.Blocking = true; //使用阻塞模式，即同步模式
            m_protocolFlag = ProtocolFlag.None;
            SocketTimeOutMS = ProtocolConst.SocketTimeOutMS;
            m_outgoingDataAssembler = new OutgoingDataAssembler();
            m_recvBuffer = new DynamicBufferManager(ProtocolConst.ReceiveBufferSize);
            m_incomingDataParser = new IncomingDataParser();
            m_sendBuffer = new DynamicBufferManager(ProtocolConst.ReceiveBufferSize);
        }

        public void Connect(string host, int port)
        {
            m_tcpClient.Connect(host, port);
            byte[] socketFlag = new byte[1];
            socketFlag[0] = (byte)m_protocolFlag;
            m_tcpClient.Client.Send(socketFlag, SocketFlags.None); //发送标识
            m_host = host;
            m_port = port;
        }

        public void Disconnect()
        {
            m_tcpClient.Close();
            m_tcpClient = new TcpClient();
            //m_tcpClient.Client.
        }

        public void SendCommand()
        {
            string commandText = m_outgoingDataAssembler.GetProtocolText();
            byte[] bufferUTF8 = Encoding.UTF8.GetBytes(commandText);
            int totalLength = sizeof(int) + bufferUTF8.Length; //获取总大小
            m_sendBuffer.Clear();
            m_sendBuffer.WriteInt(totalLength, false); //写入总大小
            m_sendBuffer.WriteInt(bufferUTF8.Length, false); //写入命令大小
            m_sendBuffer.WriteBuffer(bufferUTF8); //写入命令内容
            m_tcpClient.Client.Send(m_sendBuffer.Buffer, 0, m_sendBuffer.DataCount, SocketFlags.None); //使用阻塞模式，Socket会一次发送完所有数据后才返回
        }
        /// <summary>
        /// 发送命令，主要是对数据进行组包，然后调用发送函数发送
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        public void SendCommand(byte[] buffer, int offset, int count)
        {
            string commandText = m_outgoingDataAssembler.GetProtocolText();
            byte[] bufferUTF8 = Encoding.UTF8.GetBytes(commandText);
            int totalLength = sizeof(int) + bufferUTF8.Length + count; //获取总大小
            m_sendBuffer.Clear();
            m_sendBuffer.WriteInt(totalLength, false); //写入总大小
            m_sendBuffer.WriteInt(bufferUTF8.Length, false); //写入命令大小
            m_sendBuffer.WriteBuffer(bufferUTF8); //写入命令内容
            m_sendBuffer.WriteBuffer(buffer, offset, count); //写入二进制数据
            m_tcpClient.Client.Send(m_sendBuffer.Buffer, 0, m_sendBuffer.DataCount, SocketFlags.None);
        }
        /// <summary>
        /// 接收命令
        /// </summary>
        /// <returns></returns>
        public bool RecvCommand()
        {
            m_recvBuffer.Clear();
            m_tcpClient.Client.Receive(m_recvBuffer.Buffer, sizeof(int), SocketFlags.None);
            int packetLength = BitConverter.ToInt32(m_recvBuffer.Buffer, 0); //获取包长度
            if (NetByteOrder)
                packetLength = System.Net.IPAddress.NetworkToHostOrder(packetLength); //把网络字节顺序转为本地字节顺序
            m_recvBuffer.SetBufferSize(sizeof(int) + packetLength); //保证接收有足够的空间
            m_tcpClient.Client.Receive(m_recvBuffer.Buffer, sizeof(int), packetLength, SocketFlags.None);
            int commandLen = BitConverter.ToInt32(m_recvBuffer.Buffer, sizeof(int)); //取出命令长度
            string tmpStr = Encoding.UTF8.GetString(m_recvBuffer.Buffer, sizeof(int) + sizeof(int), commandLen);
            if (!m_incomingDataParser.DecodeProtocolText(tmpStr)) //解析命令
                return false;
            else
                return true;
        }
        /// <summary>
        /// 接收命令，先接收长度，然后接收内容，然后对数据进行解包
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="size"></param>
        /// <returns></returns>
        public bool RecvCommand(out byte[] buffer, out int offset, out int size)
        {
            m_recvBuffer.Clear();
            m_tcpClient.Client.Receive(m_recvBuffer.Buffer, sizeof(int), SocketFlags.None);
            int packetLength = BitConverter.ToInt32(m_recvBuffer.Buffer, 0); //获取包长度
            if (NetByteOrder)
                packetLength = System.Net.IPAddress.NetworkToHostOrder(packetLength); //把网络字节顺序转为本地字节顺序
            m_recvBuffer.SetBufferSize(sizeof(int) + packetLength); //保证接收有足够的空间
            m_tcpClient.Client.Receive(m_recvBuffer.Buffer, sizeof(int), packetLength, SocketFlags.None);
            int commandLen = BitConverter.ToInt32(m_recvBuffer.Buffer, sizeof(int)); //取出命令长度
            string tmpStr = Encoding.UTF8.GetString(m_recvBuffer.Buffer, sizeof(int) + sizeof(int), commandLen);
            if (!m_incomingDataParser.DecodeProtocolText(tmpStr)) //解析命令
            {
                buffer = null;
                offset = 0;
                size = 0;
                return false;
            }
            else
            {
                buffer = m_recvBuffer.Buffer;
                offset = commandLen + sizeof(int) + sizeof(int);
                size = packetLength - offset;
                return true;
            }
        }
    }
}
