using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;
using System.IO;

namespace NETIOCPSvr
{
    /// <summary>
    ///  远程流协议实现
    /// </summary>
    public class RemoteStreamSocketProtocol : BaseSocketProtocol
    {
        private FileStream m_fileStream;
        private byte[] m_readBuffer;

        public RemoteStreamSocketProtocol(AsyncSocketServer asyncSocketServer, AsyncSocketUserToken asyncSocketUserToken)
            : base(asyncSocketServer, asyncSocketUserToken)
        {
            m_socketFlag = "RemoteStream";
            m_fileStream = null;
        }

        public override void Close()
        {
            base.Close();
            if (m_fileStream != null)
                m_fileStream.Close();
            m_fileStream = null;
        }
        /// <summary>
        /// 远程流协议实现心跳协议
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        /// <returns></returns>
        public override bool ProcessCommand(byte[] buffer, int offset, int count) //处理分完包的数据，子类从这个方法继承
        {
            RemoteStreamSocketCommand command = StrToCommand(m_incomingDataParser.Command);
            m_outgoingDataAssembler.Clear();
            m_outgoingDataAssembler.AddResponse();
            m_outgoingDataAssembler.AddCommand(m_incomingDataParser.Command);
            if (command == RemoteStreamSocketCommand.FileExists)
                return DoFileExists();
            else if (command == RemoteStreamSocketCommand.OpenFile)
                return DoOpenFile();
            else if (command == RemoteStreamSocketCommand.SetSize)
                return DoSetSize();
            else if (command == RemoteStreamSocketCommand.GetSize)
                return DoGetSize();
            else if (command == RemoteStreamSocketCommand.SetPosition)
                return DoSetPosition();
            else if (command == RemoteStreamSocketCommand.GetPosition)
                return DoGetPosition();
            else if (command == RemoteStreamSocketCommand.Read)
                return DoRead();
            else if (command == RemoteStreamSocketCommand.Write)
                return DoWrite(buffer, offset, count);
            else if (command == RemoteStreamSocketCommand.Seek)
                return DoSeek();
            else if (command == RemoteStreamSocketCommand.CloseFile)
                return DoCloseFile();
            else
            {
                Program.Logger.Error("Unknow command: " + m_incomingDataParser.Command);
                return false;
            }
        }

        public RemoteStreamSocketCommand StrToCommand(string command)
        {
            if (command.Equals(ProtocolKey.FileExists, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.FileExists;
            else if (command.Equals(ProtocolKey.OpenFile, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.OpenFile;
            else if (command.Equals(ProtocolKey.SetSize, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.SetSize;
            else if (command.Equals(ProtocolKey.GetSize, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.GetSize;
            else if (command.Equals(ProtocolKey.SetPosition, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.SetPosition;
            else if (command.Equals(ProtocolKey.GetPosition, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.GetPosition;
            else if (command.Equals(ProtocolKey.Read, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.Read;
            else if (command.Equals(ProtocolKey.Write, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.Write;
            else if (command.Equals(ProtocolKey.Seek, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.Seek;
            else if (command.Equals(ProtocolKey.CloseFile, StringComparison.CurrentCultureIgnoreCase))
                return RemoteStreamSocketCommand.CloseFile;
            else
                return RemoteStreamSocketCommand.None;
        }

        public bool DoFileExists()
        {
            string filename = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.FileName, ref filename))
            {
                if (File.Exists(filename))
                    m_outgoingDataAssembler.AddSuccess();
                else
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.FileNotExist, "file not exists");
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoOpenFile()
        {
            string filename = "";
            short mode = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.FileName, ref filename) & m_incomingDataParser.GetValue(ProtocolKey.Mode, ref mode))
            {
                RemoteStreamMode readWriteMode = (RemoteStreamMode)mode;
                if (File.Exists(filename))
                {
                    if (readWriteMode == RemoteStreamMode.Read)
                        m_fileStream = new FileStream(filename, FileMode.Open, FileAccess.Read);
                    else
                        m_fileStream = new FileStream(filename, FileMode.Open, FileAccess.ReadWrite);
                }
                else
                    m_fileStream = new FileStream(filename, FileMode.Create, FileAccess.ReadWrite);
                m_outgoingDataAssembler.AddSuccess();
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoSetSize()
        {
            long fileSize = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.Size, ref fileSize))
            {
                if (m_fileStream == null)
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
                else
                {
                    m_fileStream.SetLength(fileSize);
                    m_outgoingDataAssembler.AddSuccess();
                }
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoGetSize()
        {
            if (m_fileStream == null)
                m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
            else
            {
                m_outgoingDataAssembler.AddSuccess();
                m_outgoingDataAssembler.AddValue(ProtocolKey.Size, m_fileStream.Length);
            }
            return DoSendResult();
        }

        public bool DoSetPosition()
        {
            long position = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.Position, ref position))
            {
                if (m_fileStream == null)
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
                else
                {
                    m_fileStream.Position = position;
                    m_outgoingDataAssembler.AddSuccess();
                }
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoGetPosition()
        {
            if (m_fileStream == null)
                m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
            else
            {
                m_outgoingDataAssembler.AddSuccess();
                m_outgoingDataAssembler.AddValue(ProtocolKey.Position, m_fileStream.Position);
            }
            return DoSendResult();
        }

        public bool DoRead()
        {
            int count = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.Count, ref count))
            {
                if (m_fileStream == null)
                {
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
                }
                else
                {
                    if (m_readBuffer == null)
                        m_readBuffer = new byte[count];
                    else if (m_readBuffer.Length < count) //避免多次申请内存
                        m_readBuffer = new byte[count];
                    count = m_fileStream.Read(m_readBuffer, 0, count);
                    m_outgoingDataAssembler.AddSuccess();
                    m_outgoingDataAssembler.AddValue(ProtocolKey.Count, count); //返回读取个数
                }
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult(m_readBuffer, 0, count);
        }

        public bool DoWrite(byte[] buffer, int offset, int count)
        {
            if (m_fileStream == null)
                m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
            else
            {
                m_fileStream.Write(buffer, offset, count);
                m_outgoingDataAssembler.AddSuccess();
                m_outgoingDataAssembler.AddValue(ProtocolKey.Count, count); //返回写入个数
            }
            return DoSendResult();
        }

        public bool DoSeek()
        {
            long offset = 0;
            int seekOrign = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.Offset, ref offset) & m_incomingDataParser.GetValue(ProtocolKey.SeekOrigin, ref seekOrign))
            {
                if (m_fileStream == null)
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
                else
                {
                    offset = m_fileStream.Seek(offset, (SeekOrigin)seekOrign);
                    m_outgoingDataAssembler.AddSuccess();
                    m_outgoingDataAssembler.AddValue(ProtocolKey.Offset, offset);
                }
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoCloseFile()
        {
            if (m_fileStream == null)
                m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
            else
            {
                m_fileStream.Close();
                m_fileStream = null;
                m_outgoingDataAssembler.AddSuccess();
            }
            return DoSendResult();
        }
    }
}
