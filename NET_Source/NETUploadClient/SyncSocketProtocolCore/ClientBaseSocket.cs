using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NETUploadClient.SyncSocketCore;

namespace NETUploadClient.SyncSocketProtocolCore
{
    public class ClientBaseSocket : SyncSocketInvokeElement
    {
        protected string m_errorString;
        public string ErrorString { get { return m_errorString; } }
        protected string m_userName;
        protected string m_password;

        public ClientBaseSocket()
            : base()
        {
        }

        public bool CheckErrorCode()
        {
            int errorCode = 0;
            m_incomingDataParser.GetValue(NETIOCPSvr.ProtocolKey.Code, ref errorCode);
            if (errorCode == NETIOCPSvr.ProtocolCode.Success)
                return true;
            else
            {
                m_errorString = NETIOCPSvr.ProtocolCode.GetErrorCodeString(errorCode);
                return false;
            }
        }

        public bool DoActive()
        {
            try
            {
                m_outgoingDataAssembler.Clear();
                m_outgoingDataAssembler.AddRequest();
                m_outgoingDataAssembler.AddCommand(NETIOCPSvr.ProtocolKey.Active);
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

        public bool DoLogin(string userName, string password)
        {
            try
            {
                m_outgoingDataAssembler.Clear();
                m_outgoingDataAssembler.AddRequest();
                m_outgoingDataAssembler.AddCommand(NETIOCPSvr.ProtocolKey.Login);
                m_outgoingDataAssembler.AddValue(NETIOCPSvr.ProtocolKey.UserName, userName);
                m_outgoingDataAssembler.AddValue(NETIOCPSvr.ProtocolKey.Password, NETIOCPSvr.BasicFunc.MD5String(password));
                SendCommand();
                bool bSuccess = RecvCommand();
                if (bSuccess)
                {
                    bSuccess = CheckErrorCode();
                    if (bSuccess)
                    {
                        m_userName = userName;
                        m_password = password;
                    }
                    return bSuccess;
                }
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

        public bool ReConnect()
        {
            if (m_tcpClient.Connected && (!DoActive()))
                return true;
            else
            {
                if (!m_tcpClient.Connected)
                {
                    try
                    {
                        Connect(m_host, m_port);
                        return true;
                    }
                    catch (Exception)
                    {
                        return false;
                    }
                }
                else
                    return true;
            }
        }

        public bool ReConnectAndLogin()
        {
            if (m_tcpClient.Connected && (!DoActive()))
                return true;
            else
            {
                if (!m_tcpClient.Connected)
                {
                    try
                    {
                        Disconnect();
                        Connect(m_host, m_port);
                        return DoLogin(m_userName, m_password);
                    }
                    catch (Exception E)
                    {
                        return false;
                    }
                }
                else
                    return true;
            }
        }
    }
}
