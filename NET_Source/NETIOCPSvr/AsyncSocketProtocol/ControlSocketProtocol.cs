using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;

namespace NETIOCPSvr
{
    /// <summary>
    /// 控制协议实现
    /// </summary>
    public class ControlSocketProtocol : BaseSocketProtocol
    {
        public ControlSocketProtocol(AsyncSocketServer asyncSocketServer, AsyncSocketUserToken asyncSocketUserToken)
            : base(asyncSocketServer, asyncSocketUserToken)
        {
            m_socketFlag = "Control";
        }

        public override void Close()
        {
            base.Close();
        }
        /// <summary>
        /// 控制协议实现心跳协议
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        /// <returns></returns>
        public override bool ProcessCommand(byte[] buffer, int offset, int count) //处理分完包的数据，子类从这个方法继承
        {
            ControlSocketCommand command = StrToCommand(m_incomingDataParser.Command);
            m_outgoingDataAssembler.Clear();
            m_outgoingDataAssembler.AddResponse();
            m_outgoingDataAssembler.AddCommand(m_incomingDataParser.Command);
            if (!CheckLogined(command)) //检测登录
            {
                m_outgoingDataAssembler.AddFailure(ProtocolCode.UserHasLogined, "");
                return DoSendResult();
            }
            if (command == ControlSocketCommand.Login)
                return DoLogin();
            else if (command == ControlSocketCommand.Active)
                return DoActive();
            else if (command == ControlSocketCommand.GetClients)
                return DoGetClients();
            else
            {
                Program.Logger.Error("Unknow command: " + m_incomingDataParser.Command);
                return false;
            }
        }

        public ControlSocketCommand StrToCommand(string command)
        {
            if (command.Equals(ProtocolKey.Active, StringComparison.CurrentCultureIgnoreCase))
                return ControlSocketCommand.Active;
            else if (command.Equals(ProtocolKey.Login, StringComparison.CurrentCultureIgnoreCase))
                return ControlSocketCommand.Login;
            else if (command.Equals(ProtocolKey.GetClients, StringComparison.CurrentCultureIgnoreCase))
                return ControlSocketCommand.GetClients;
            else
                return ControlSocketCommand.None;
        }

        public bool CheckLogined(ControlSocketCommand command)
        {
            if ((command == ControlSocketCommand.Login) | (command == ControlSocketCommand.Active))
                return true;
            else
                return m_logined;
        }

        public bool DoGetClients()
        {
            AsyncSocketUserToken[] userTokenArray = null;
            m_asyncSocketServer.AsyncSocketUserTokenList.CopyList(ref userTokenArray);
            m_outgoingDataAssembler.AddSuccess();
            string socketText = "";
            for (int i = 0; i < userTokenArray.Length; i++)
            {
                try
                {
                    socketText = userTokenArray[i].ConnectSocket.LocalEndPoint.ToString() + "\t"
                        + userTokenArray[i].ConnectSocket.RemoteEndPoint.ToString() + "\t"
                        + (userTokenArray[i].AsyncSocketInvokeElement as BaseSocketProtocol).SocketFlag + "\t"
                        + (userTokenArray[i].AsyncSocketInvokeElement as BaseSocketProtocol).UserName + "\t"
                        + userTokenArray[i].AsyncSocketInvokeElement.ConnectDT.ToString() + "\t"
                        + userTokenArray[i].AsyncSocketInvokeElement.ActiveDT.ToString();
                    m_outgoingDataAssembler.AddValue(ProtocolKey.Item, socketText);
                }
                catch (Exception E)
                {
                    Program.Logger.ErrorFormat("Get client error, message: {0}", E.Message);
                    Program.Logger.Error(E.StackTrace);
                }
            }
            return DoSendResult();
        }
    }
}
