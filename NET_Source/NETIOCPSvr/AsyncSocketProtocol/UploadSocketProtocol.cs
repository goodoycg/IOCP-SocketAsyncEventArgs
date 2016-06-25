using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;
using System.IO;

namespace NETIOCPSvr
{
    /// <summary>
    /// 上传协议实现、
    /// </summary>
    public class UploadSocketProtocol : BaseSocketProtocol
    {
        private string m_fileName;
        public string FileName { get { return m_fileName; } }
        private FileStream m_fileStream;

        public UploadSocketProtocol(AsyncSocketServer asyncSocketServer, AsyncSocketUserToken asyncSocketUserToken)
            : base(asyncSocketServer, asyncSocketUserToken)
        {
            m_socketFlag = "Upload";
            m_fileName = "";
            m_fileStream = null;
            lock (m_asyncSocketServer.UploadSocketProtocolMgr)
            {
                m_asyncSocketServer.UploadSocketProtocolMgr.Add(this);
            }
        }

        public override void Close()
        {
            base.Close();
            m_fileName = "";
            if (m_fileStream != null)
            {
                m_fileStream.Close();
                m_fileStream = null;
            }
            lock (m_asyncSocketServer.UploadSocketProtocolMgr)
            {
                m_asyncSocketServer.UploadSocketProtocolMgr.Remove(this);
            }
        }
        /// <summary>
        /// 上传协议实现心跳协议
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        /// <returns></returns>
        public override bool ProcessCommand(byte[] buffer, int offset, int count) //处理分完包的数据，子类从这个方法继承
        {
            UploadSocketCommand command = StrToCommand(m_incomingDataParser.Command);
            m_outgoingDataAssembler.Clear();
            m_outgoingDataAssembler.AddResponse();
            m_outgoingDataAssembler.AddCommand(m_incomingDataParser.Command);
            if (!CheckLogined(command)) //检测登录
            {
                m_outgoingDataAssembler.AddFailure(ProtocolCode.UserHasLogined, "");
                return DoSendResult();
            }
            if (command == UploadSocketCommand.Login)
                return DoLogin();
            else if (command == UploadSocketCommand.Active)
                return DoActive();
            else if (command == UploadSocketCommand.Dir)
                return DoDir();
            else if (command == UploadSocketCommand.CreateDir)
                return DoCreateDir();
            else if (command == UploadSocketCommand.DeleteDir)
                return DoDeleteDir();
            else if (command == UploadSocketCommand.FileList)
                return DoFileList();
            else if (command == UploadSocketCommand.DeleteFile)
                return DoDeleteFile();
            else if (command == UploadSocketCommand.Upload)
                return DoUpload();
            else if (command == UploadSocketCommand.Data)
                return DoData(buffer, offset, count);
            else if (command == UploadSocketCommand.Eof)
                return DoEof();
            else
            {
                Program.Logger.Error("Unknow command: " + m_incomingDataParser.Command);
                return false;
            }
        }

        public UploadSocketCommand StrToCommand(string command)
        {
            if (command.Equals(ProtocolKey.Active, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.Active;
            else if (command.Equals(ProtocolKey.Login, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.Login;
            else if (command.Equals(ProtocolKey.Dir, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.Dir;
            else if (command.Equals(ProtocolKey.CreateDir, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.CreateDir;
            else if (command.Equals(ProtocolKey.DeleteDir, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.DeleteDir;
            else if (command.Equals(ProtocolKey.FileList, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.FileList;
            else if (command.Equals(ProtocolKey.DeleteFile, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.DeleteFile;
            else if (command.Equals(ProtocolKey.Upload, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.Upload;
            else if (command.Equals(ProtocolKey.Data, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.Data;
            else if (command.Equals(ProtocolKey.Eof, StringComparison.CurrentCultureIgnoreCase))
                return UploadSocketCommand.Eof;
            else
                return UploadSocketCommand.None;
        }

        public bool CheckLogined(UploadSocketCommand command)
        {
            if ((command == UploadSocketCommand.Login) | (command == UploadSocketCommand.Active))
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

        public bool DoCreateDir()
        {
            string parentDir = "";
            string dirName = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.ParentDir, ref parentDir) & m_incomingDataParser.GetValue(ProtocolKey.DirName, ref dirName))
            {
                if (parentDir == "")
                    parentDir = Program.FileDirectory;
                else
                    parentDir = Path.Combine(Program.FileDirectory, parentDir);                
                if (Directory.Exists(parentDir))
                {
                    try
                    {
                        parentDir = Path.Combine(parentDir, dirName);
                        Directory.CreateDirectory(parentDir);
                        m_outgoingDataAssembler.AddSuccess();
                    }
                    catch (Exception E)
                    {
                        m_outgoingDataAssembler.AddFailure(ProtocolCode.CreateDirError, E.Message);
                    }
                }
                else
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.DirNotExist, "");
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }

        public bool DoDeleteDir()
        {
            string parentDir = "";
            string dirName = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.ParentDir, ref parentDir) & m_incomingDataParser.GetValue(ProtocolKey.DirName, ref dirName))
            {
                if (parentDir == "")
                    parentDir = Program.FileDirectory;
                else
                    parentDir = Path.Combine(Program.FileDirectory, parentDir);
                if (Directory.Exists(parentDir))
                {
                    try
                    {
                        parentDir = Path.Combine(parentDir, dirName);
                        Directory.Delete(parentDir, true);
                        m_outgoingDataAssembler.AddSuccess();
                    }
                    catch (Exception E)
                    {
                        m_outgoingDataAssembler.AddFailure(ProtocolCode.DeleteDirError, E.Message);
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

        public bool DoDeleteFile()
        {
            string dirName = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.DirName, ref dirName))
            {
                if (dirName == "")
                    dirName = Program.FileDirectory;
                else
                    dirName = Path.Combine(Program.FileDirectory, dirName);
                string fileName = "";
                if (Directory.Exists(dirName))
                {
                    try
                    {
                        List<string> files = m_incomingDataParser.GetValue(ProtocolKey.Item);
                        for (int i = 0; i < files.Count; i++)
                        {
                            fileName = Path.Combine(dirName, files[i]);
                            File.Delete(fileName);
                        }
                        m_outgoingDataAssembler.AddSuccess();
                    }
                    catch (Exception E)
                    {
                        m_outgoingDataAssembler.AddFailure(ProtocolCode.DeleteFileFailed, E.Message);
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
        /// 上传断点续传
        /// </summary>
        /// <returns></returns>
        public bool DoUpload()
        {
            string dirName = "";
            string fileName = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.DirName, ref dirName) & m_incomingDataParser.GetValue(ProtocolKey.FileName, ref fileName))
            {
                if (dirName == "")
                    dirName = Program.FileDirectory;
                else
                    dirName = Path.Combine(Program.FileDirectory, dirName);
                fileName = Path.Combine(dirName, fileName);
                Program.Logger.Info("Start upload file: " + fileName);
                if (m_fileStream != null) //关闭上次传输的文件
                {
                    m_fileStream.Close();
                    m_fileStream = null;
                    m_fileName = "";
                }
                if (File.Exists(fileName))
                {
                    if (!CheckFileInUse(fileName)) //检测文件是否正在使用中
                    {
                        m_fileName = fileName;
                        m_fileStream = new FileStream(fileName, FileMode.Open, FileAccess.ReadWrite);
                        m_fileStream.Position = m_fileStream.Length; //文件移到末尾
                        m_outgoingDataAssembler.AddSuccess();
                        m_outgoingDataAssembler.AddValue(ProtocolKey.FileSize, m_fileStream.Length);
                    }
                    else
                    {
                        m_outgoingDataAssembler.AddFailure(ProtocolCode.FileIsInUse, "");
                        Program.Logger.Error("Start upload file error, file is in use: " + fileName);
                    }
                }
                else
                {
                    m_fileName = fileName;
                    m_fileStream = new FileStream(fileName, FileMode.OpenOrCreate, FileAccess.ReadWrite);
                    m_fileStream.Position = m_fileStream.Length; //文件移到末尾
                    m_outgoingDataAssembler.AddSuccess();
                    m_outgoingDataAssembler.AddValue(ProtocolKey.FileSize, m_fileStream.Length);
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
                lock (m_asyncSocketServer.UploadSocketProtocolMgr)
                {
                    UploadSocketProtocol uploadSocketProtocol = null;
                    for (int i = 0; i < m_asyncSocketServer.UploadSocketProtocolMgr.Count(); i++)
                    {
                        uploadSocketProtocol = m_asyncSocketServer.UploadSocketProtocolMgr.ElementAt(i);
                        if (fileName.Equals(uploadSocketProtocol.FileName, StringComparison.CurrentCultureIgnoreCase))
                        {
                            lock (uploadSocketProtocol.AsyncSocketUserToken) //AsyncSocketUserToken有多个
                            {
                                m_asyncSocketServer.CloseClientSocket(uploadSocketProtocol.AsyncSocketUserToken);
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

        public bool DoData(byte[] buffer, int offset, int count)
        {
            if (m_fileStream == null)
            {
                m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
                return false;
            }
            else
            {
                m_fileStream.Write(buffer, offset, count);
                return true;
                //m_outgoingDataAssembler.AddSuccess();
                //m_outgoingDataAssembler.AddValue(ProtocolKey.Count, count); //返回读取个数
            }
            //return DoSendResult(); //接收数据不发回响应
        }

        public bool DoEof()
        {
            if (m_fileStream == null)
                m_outgoingDataAssembler.AddFailure(ProtocolCode.NotOpenFile, "");
            else
            {
                Program.Logger.Info("End upload file: " + m_fileName);
                m_fileStream.Close();
                m_fileStream = null;
                m_fileName = "";
                m_outgoingDataAssembler.AddSuccess();
            }
            return DoSendResult();
        }
    }

    public class UploadSocketProtocolMgr : Object
    {
        private List<UploadSocketProtocol> m_list;

        public UploadSocketProtocolMgr()
        {
            m_list = new List<UploadSocketProtocol>();
        }

        public int Count()
        {
            return m_list.Count;
        }

        public UploadSocketProtocol ElementAt(int index)
        {
            return m_list.ElementAt(index);
        }

        public void Add(UploadSocketProtocol value)
        {
            m_list.Add(value);
        }

        public void Remove(UploadSocketProtocol value)
        {
            m_list.Remove(value);
        }
    }
}
