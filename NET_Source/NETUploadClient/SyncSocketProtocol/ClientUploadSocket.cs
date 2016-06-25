using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NETUploadClient.SyncSocketProtocolCore;

namespace NETUploadClient.SyncSocketProtocol
{
    /// <summary>
    /// 上传协议主要分为三个命令，第一个是Upload，向服务器请求上传的文件，
    /// 如果服务器有相同的文件，则返回是否传完，如果未传完，返回需要续传的文件位置，
    /// 然后客户端则从上一个位置开始传输，传输数据服务器只接收，不应答，
    /// 客户端传输完后，发完成（EOF）命令。
    /// </summary>
    class ClientUploadSocket : ClientBaseSocket
    {
        public ClientUploadSocket()
            : base()
        {
            m_protocolFlag = NETIOCPSvr.ProtocolFlag.Upload;
        }
        /// <summary>
        /// 向服务器请求上传的文件
        /// </summary>
        /// <param name="dirName"></param>
        /// <param name="fileName"></param>
        /// <param name="fileSize"></param>
        /// <returns></returns>
        public bool DoUpload(string dirName, string fileName, ref long fileSize)
        {
            bool bConnect = ReConnectAndLogin(); //检测连接是否还在，如果断开则重连并登录
            if (!bConnect)
                return bConnect;
            try
            {
                m_outgoingDataAssembler.Clear();
                m_outgoingDataAssembler.AddRequest();
                m_outgoingDataAssembler.AddCommand(NETIOCPSvr.ProtocolKey.Upload);
                m_outgoingDataAssembler.AddValue(NETIOCPSvr.ProtocolKey.DirName, dirName);
                m_outgoingDataAssembler.AddValue(NETIOCPSvr.ProtocolKey.FileName, fileName);
                SendCommand();
                bool bSuccess = RecvCommand();
                if (bSuccess)
                {
                    bSuccess = CheckErrorCode();
                    if (bSuccess)
                    {
                        bSuccess = m_incomingDataParser.GetValue(NETIOCPSvr.ProtocolKey.FileSize, ref fileSize);
                    }
                    return bSuccess;
                }
                else
                    return false;
            }
            catch (Exception E)
            {//记录日志
                m_errorString = E.Message;
                return false;
            }
        }
        /// <summary>
        /// 上一个位置开始传输，传输数据服务器只接收，不应答
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        /// <returns></returns>
        public bool DoData(byte[] buffer, int offset, int count)
        {
            try
            {
                m_outgoingDataAssembler.Clear();
                m_outgoingDataAssembler.AddRequest();
                m_outgoingDataAssembler.AddCommand(NETIOCPSvr.ProtocolKey.Data);
                SendCommand(buffer, offset, count);
                return true;
            }
            catch (Exception E)
            {
                //记录日志
                m_errorString = E.Message;
                return false;
            }
        }
        /// <summary>
        /// 发完成（EOF）命令
        /// </summary>
        /// <param name="fileSize"></param>
        /// <returns></returns>
        public bool DoEof(Int64 fileSize)
        {
            try
            {
                m_outgoingDataAssembler.Clear();
                m_outgoingDataAssembler.AddRequest();
                m_outgoingDataAssembler.AddCommand(NETIOCPSvr.ProtocolKey.Eof);
                SendCommand();
                bool bSuccess = RecvCommand();
                if (bSuccess)
                    return CheckErrorCode();
                else
                    return false;
            }
            catch (Exception E)
            {
                //记录日志
                m_errorString = E.Message;
                return false;
            }
        }
    }
}
