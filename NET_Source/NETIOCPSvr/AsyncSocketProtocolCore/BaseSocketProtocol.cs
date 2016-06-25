using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;

namespace NETIOCPSvr
{
    /// <summary>
    /// 所有协议的基类，把一些公共的方法放在这里
    /// 后续的ControlSocketProtocol、DownloadSocketProtocol、
    /// LogOutputSocketProtocol、RemoteStreamSocketProtocol、
    /// ThroughputSocketProtocol、UploadSocketProtocol都从这里继承
    /// </summary>
    public class BaseSocketProtocol : AsyncSocketInvokeElement
    {
        protected string m_userName;
        public string UserName { get { return m_userName; } }
        protected bool m_logined;
        public bool Logined { get { return m_logined; } }
        protected string m_socketFlag;
        public string SocketFlag { get { return m_socketFlag; } }

        public BaseSocketProtocol(AsyncSocketServer asyncSocketServer, AsyncSocketUserToken asyncSocketUserToken)
            : base(asyncSocketServer, asyncSocketUserToken)
        {
            m_userName = "";
            m_logined = false;
            m_socketFlag = "";
        }

        public bool DoLogin()
        {
            string userName = "";
            string password = "";
            if (m_incomingDataParser.GetValue(ProtocolKey.UserName, ref userName) & m_incomingDataParser.GetValue(ProtocolKey.Password, ref password))
            {
                if (password.Equals(BasicFunc.MD5String("admin"), StringComparison.CurrentCultureIgnoreCase))
                {
                    m_outgoingDataAssembler.AddSuccess();
                    m_userName = userName;
                    m_logined = true;
                    Program.Logger.InfoFormat("{0} login success", userName);
                }
                else
                {
                    m_outgoingDataAssembler.AddFailure(ProtocolCode.UserOrPasswordError, "");
                    Program.Logger.ErrorFormat("{0} login failure,password error", userName);
                }
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult();
        }
        /// <summary>
        /// 心跳包
        /// 有超时连接，相对应的需要设计心跳包，心跳包用来检测连接和维护连接状态，
        /// 心跳包的原理是客户端发送一个包给服务器，服务器收到后发一个响应包给客户端，
        /// 通过检测是否有返回来判断连接是否正常。
        /// </summary>
        /// <returns></returns>
        public bool DoActive()
        {
            m_outgoingDataAssembler.AddSuccess();
            return DoSendResult();
        }
    }
}
