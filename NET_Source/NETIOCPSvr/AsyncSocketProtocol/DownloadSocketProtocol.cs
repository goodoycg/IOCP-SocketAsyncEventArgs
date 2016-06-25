using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;
using System.IO;

namespace NETIOCPSvr
{
    /// <summary>
    /// 下载协议实现
    /// </summary>
    public class DownloadSocketProtocol : BaseSocketProtocol
    {
        private string m_fileName;
        public string FileName { get { return m_fileName; } }
        private FileStream m_fileStream;
        private bool m_sendFile;
        private int m_packetSize;
        private byte[] m_readBuffer;

        public DownloadSocketProtocol(AsyncSocketServer asyncSocketServer, AsyncSocketUserToken asyncSocketUserToken)
            : base(asyncSocketServer, asyncSocketUserToken)
        {
            m_socketFlag = "Download";
            m_fileName = "";
            m_fileStream = null;
            m_sendFile = false;
            m_packetSize = 64 * 1024;
            lock (m_asyncSocketServer.DownloadSocketProtocolMgr)
            {
                m_asyncSocketServer.DownloadSocketProtocolMgr.Add(this);
            }
        }

        public override void Close()
        {
            base.Close();
            m_fileName = "";
            m_sendFile = false;
            if (m_fileStream != null)
            {
                m_fileStream.Close();
                m_fileStream = null;
            }
            lock (m_asyncSocketServer)
            {
                m_asyncSocketServer.DownloadSocketProtocolMgr.Remove(this);
            }
        }
        /// <summary>
        /// 下载协议实现心跳协议
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        /// <returns></returns>
        public override bool ProcessCommand(byte[] buffer, int offset, int count) //处理分完包的数据，子类从这个方法继承
        {
            DownloadSocketCommand command = StrToCommand(m_incomingDataParser.Command);
            m_outgoingDataAssembler.Clear();
            m_outgoingDataAssembler.AddResponse();
            m_outgoingDataAssembler.AddCommand(m_incomingDataParser.Command);
            if (!CheckLogined(command)) //检测登录
            {
                m_outgoingDataAssembler.AddFailure(ProtocolCode.UserHasLogined, "");
                return DoSendResult();
            }
            if (command == DownloadSocketCommand.Login)
                return DoLogin();
            else if (command == DownloadSocketCommand.Active)
                return DoActive();
            else if (command == DownloadSocketCommand.Dir)
                return DoDir();
            else if (command == DownloadSocketCommand.FileList)
                return DoFileList();
            else if (command == DownloadSocketCommand.Download)
                return DoDownload();
            else
            {
                Program.Logger.Error("Unknow command: " + m_incomingDataParser.Command);
                return false;
            }
        }

        public DownloadSocketCommand StrToCommand(string command)
        {
            if (command.Equals(ProtocolKey.Active, StringComparison.CurrentCultureIgnoreCase))
                return DownloadSocketCommand.Active;
            else if (command.Equals(ProtocolKey.Login, StringComparison.CurrentCultureIgnoreCase))
                return DownloadSocketCommand.Login;
            else if (command.Equals(ProtocolKey.Dir, StringComparison.CurrentCultureIgnoreCase))
                return DownloadSocketCommand.Dir;
            else if (command.Equals(ProtocolKey.FileList, StringComparison.CurrentCultureIgnoreCase))
                return DownloadSocketCommand.FileList;
            else if (command.Equals(ProtocolKey.Download, StringComparison.CurrentCultureIgnoreCase))
                return DownloadSocketCommand.Download;
            else
                return DownloadSocketCommand.None;
        }

        public bool CheckLogined(DownloadSocketCommand command)
        {
            if ((command == DownloadSocketCommand.Login) | (command == DownloadSocketCommand.Active))
                return true;
            else
                return m_logined;
        }

        public bool DoDir()
        {
            string parentDir = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.ParentDir, ref parentDir))
            {
                if (parentDir == "")
                    parentDir = Program.FileDirectory;
                else
                    parentDir = Path.Combine(Program.FileDirectory, parentDir);
                if (Directory.Exists(parentDir))
                {
                    string[] subDirectorys = Directory.GetDirectories(parentDir, "*", SearchOption.TopDirectoryOnly);
                    m_outgoingDataAssembler.AddSuccess();
                    char[] directorySeparator = new char[1];
                    directorySeparator[0] = Path.DirectorySeparatorChar;
                    for (int i = 0; i < subDirectorys.Length; i++)
                    {
                        string[] directoryName = subDirectorys[i].Split(directorySeparator, StringSplitOptions.RemoveEmptyEntries);
                        m_outgoingDataAssembler.AddValue(ProtocolKey.Item, directoryName[directoryName.Length - 1]);
                    }
                }
                else
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.DirNotExist, "");
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoFileList()
        {
            string dirName = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.DirName, ref dirName))
            {
                if (dirName == "")
                    dirName = Program.FileDirectory;
                else
                    dirName = Path.Combine(Program.FileDirectory, dirName);
                if (Directory.Exists(dirName))
                {
                    string[] files = Directory.GetFiles(dirName);
                    m_outgoingDataAssembler.AddSuccess();
                    Int64 fileSize = 0;
                    for (int i = 0; i < files.Length; i++)
                    {
                        FileInfo fileInfo = new FileInfo(files[i]);
                        fileSize = fileInfo.Length;
                        m_outgoingDataAssembler.AddValue(ProtocolKey.Item, fileInfo.Name + ProtocolKey.TextSeperator + fileSize.ToString());
                    }
                }
                else
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.DirNotExist, "");
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }
        /// <summary>
        /// 下载断点续传
        /// </summary>
        /// <returns></returns>
        public bool DoDownload()
        {
            string dirName = "";
            string fileName = "";
            Int64 fileSize = 0;
            int packetSize = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.DirName, ref dirName) & m_incomingDataParser.GetValue(ProtocolKey.FileName, ref fileName)
                & m_incomingDataParser.GetValue(ProtocolKey.FileSize, ref fileSize) & m_incomingDataParser.GetValue(ProtocolKey.PacketSize, ref packetSize))
            {
                if (dirName == "")
                    dirName = Program.FileDirectory;
                else
                    dirName = Path.Combine(Program.FileDirectory, dirName);
                fileName = Path.Combine(dirName, fileName);
                Program.Logger.Info("Start download file: " + fileName);
                if (m_fileStream != null) //关闭上次传输的文件
                {
                    m_fileStream.Close();
                    m_fileStream = null;
                    m_fileName = "";
                    m_sendFile = false;
                }
                if (File.Exists(fileName))
                {
                    if (!CheckFileInUse(fileName)) //检测文件是否正在使用中
                    {
                        m_fileName = fileName;
                        m_fileStream = new FileStream(fileName, FileMode.Open, FileAccess.ReadWrite);
                        m_fileStream.Position = fileSize; //文件移到上次下载位置
                        m_outgoingDataAssembler.AddSuccess();
                        m_sendFile = true;
                        m_packetSize = packetSize;
                    }
                    else
                    {
                        m_outgoingDataAssembler.AddFailure(ProtocolCode.FileIsInUse, "");
                        Program.Logger.Error("Start download file error, file is in use: " + fileName);
                    }
                }
                else
                {
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.FileNotExist, "");
                }
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        //检测文件是否正在使用中，如果正在使用中则检测是否被上传协议占用，如果占用则关闭,真表示正在使用中，并没有关闭
        public bool CheckFileInUse(string fileName)
        {
            if (BasicFunc.IsFileInUse(fileName))
            {
                bool result = true;
                lock (m_asyncSocketServer.DownloadSocketProtocolMgr)
                {
                    DownloadSocketProtocol downloadSocketProtocol = null;
                    for (int i = 0; i < m_asyncSocketServer.DownloadSocketProtocolMgr.Count(); i++)
                    {
                        downloadSocketProtocol = m_asyncSocketServer.DownloadSocketProtocolMgr.ElementAt(i);
                        if (fileName.Equals(downloadSocketProtocol.FileName, StringComparison.CurrentCultureIgnoreCase))
                        {
                            lock (downloadSocketProtocol.AsyncSocketUserToken) //AsyncSocketUserToken有多个线程访问
                            {
                                m_asyncSocketServer.CloseClientSocket(downloadSocketProtocol.AsyncSocketUserToken);
                            }
                            result = false;
                        }
                    }
                }
                return result;
            }
            else
                return false;
        }

        public override bool SendCallback()
        {
            bool result = base.SendCallback();
            if (m_fileStream != null)
            {
                if (m_sendFile) //发送文件头
                {
                    m_outgoingDataAssembler.Clear();
                    m_outgoingDataAssembler.AddResponse();
                    m_outgoingDataAssembler.AddCommand(ProtocolKey.SendFile);
                    m_outgoingDataAssembler.AddSuccess();
                    m_outgoingDataAssembler.AddValue(ProtocolKey.FileSize, m_fileStream.Length - m_fileStream.Position);
                    result = DoSendResult();
                    m_sendFile = false;
                }
                else
                {
                    if (m_fileStream.Position < m_fileStream.Length) //发送具体数据
                    {
                        m_outgoingDataAssembler.Clear();
                        m_outgoingDataAssembler.AddResponse();
                        m_outgoingDataAssembler.AddCommand(ProtocolKey.Data);
                        m_outgoingDataAssembler.AddSuccess();
                        if (m_readBuffer == null)
                            m_readBuffer = new byte[m_packetSize];
                        else if (m_readBuffer.Length < m_packetSize) //避免多次申请内存
                            m_readBuffer = new byte[m_packetSize];
                        int count = m_fileStream.Read(m_readBuffer, 0, m_packetSize);
                        result = DoSendResult(m_readBuffer, 0, count);
                    }
                    else //发送完成
                    {
                        Program.Logger.Info("End download file: " + m_fileName);
                        m_fileStream.Close();
                        m_fileStream = null;
                        m_fileName = "";
                        m_sendFile = false;
                        result = true;
                    }
                }
            }            
            return result;
        }
    }

    public class DownloadSocketProtocolMgr : Object
    {
        private List<DownloadSocketProtocol> m_list;

        public DownloadSocketProtocolMgr()
        {
            m_list = new List<DownloadSocketProtocol>();
        }

        public int Count()
        {
            return m_list.Count;
        }

        public DownloadSocketProtocol ElementAt(int index)
        {
            return m_list.ElementAt(index);
        }

        public void Add(DownloadSocketProtocol value)
        {
            m_list.Add(value);
        }

        public void Remove(DownloadSocketProtocol value)
        {
            m_list.Remove(value);
        }
    }
}
