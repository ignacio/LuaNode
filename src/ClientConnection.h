#pragma once

#include <boost/thread/mutex.hpp>
#include <boost/thread.hpp>

#include "Network/ISocket.h"

//#include "NetUser.h"
//#include "Users.h"

#include "EvaluadorLua.h"

class CClientConnection : public CEvaluadorLua
{
public:
	CClientConnection(inConcert::Network::IStreamSocket::Ptr socket, const char* ip);
	virtual ~CClientConnection(void);

public:
	bool ProcessCommand(const std::string& cmd);

	void Detach();

public:
	/*BEGIN_EVAL_FUNC_MAP(CClientConnection)
		EVAL_FUNC_ENTRY2(loginuser, &CClientConnection::LoginUser)
		EVAL_FUNC_ENTRY2(getusers, &CClientConnection::GetUsers)
		EVAL_FUNC_ENTRY2(getsesions, &CClientConnection::GetSesions)
		//EVAL_FUNC_ENTRY2(getchannels, &CClientConnection::GetChannels)
		EVAL_FUNC_ENTRY2(getusersinsesion, &CClientConnection::GetUsersInSesion)
		EVAL_FUNC_ENTRY2(gettextfromsesion, &CClientConnection::GetTextFromSesion)
		EVAL_FUNC_ENTRY2(connectusertosesion, &CClientConnection::ConnectUserToSesion)
		EVAL_FUNC_ENTRY2(disconnectuserfromsesion, &CClientConnection::DisconnectUserFromSesion)
		EVAL_FUNC_ENTRY2(addtexttosesion, &CClientConnection::AddTextToSesion)
		EVAL_FUNC_ENTRY2(send, &CClientConnection::Send)
		EVAL_FUNC_ENTRY2(CloseChat, &CClientConnection::CloseChat)
		EVAL_FUNC_ENTRY2(createsesion, &CClientConnection::CreateSesion)
		EVAL_FUNC_ENTRY2(deletesesion, &CClientConnection::DeleteSesion)
		EVAL_FUNC_ENTRY2(requestconnection, &CClientConnection::RequestConnection)
		EVAL_FUNC_ENTRY2(logout, &CClientConnection::Logout)
		EVAL_FUNC_ENTRY2(isconnected, &CClientConnection::IsConnected)
		EVAL_FUNC_ENTRY2(setpropertiestosesion, &CClientConnection::SetPropertiesToSesion)
		EVAL_FUNC_ENTRY2(rmvuser, &CClientConnection::LogoutUser)
		//EVAL_FUNC_ENTRY2(logon, &CClientConnection::LogOn)
		//EVAL_FUNC_ENTRY2(logoff, &CClientConnection::LogOff)
	END_EVAL_FUNC_MAP()*/

private:
	int LoginUser(lua_State* L);
	int GetUsers(lua_State* L);
	int GetChannels(lua_State* L);
	int GetSesions(lua_State* L);
	int CreateSesion(lua_State* L);
	int DeleteSesion(lua_State* L);
	int GetUsersInSesion(lua_State* L);
	int GetTextFromSesion(lua_State* L);
	int ConnectUserToSesion(lua_State* L);
	int DisconnectUserFromSesion(lua_State* L);
	int AddTextToSesion(lua_State* L);
	int Send(lua_State* L);
	int CloseChat(lua_State* L);

	int RequestConnection(lua_State* L);
	int Logout(lua_State* L);
	int IsConnected(lua_State* L);
	int SetPropertiesToSesion(lua_State* L);
	int LogoutUser(lua_State* L);
	int LogOn(lua_State* L);
	int LogOff(lua_State* L);

public:
	/*void SendOnConnectEvent(CNetUser* pUser, const CBString& sesionId, const CBString& imlData);
	void SendOnTransferEvent(CNetUser* pUser, const CBString& src_sesionId, const CBString& trg_sesionId, const CBString& imlData);
	void SendOnNewMessageEvent(CNetUser* pUser, const CBString& sesionId, const CBString& imlData);
	void SendOnDisconnectEvent(CNetUser* pUser, const CBString& sesionId, const CBString& imlData);
	void SendOnChangeSesionPropertiesEvent(CNetUser* pUser, const CBString& sesionId, const CBString& imlData);*/

private:
	bool CheckParams(lua_State* L, int nParams, LPCTSTR sMethodName);
	int ReturnString(lua_State* L, unsigned long nTranID, LPCTSTR resultValue);
	int ReturnLong(lua_State* L, unsigned long nTranID, long resultValue);
	int ReturnInteger(lua_State* L, unsigned long nTranID, int resultValue);

private:
	CBString m_clientIpAddress;

	boost::recursive_mutex m_socketAccessLock;
	inConcert::Network::IStreamSocket::Ptr m_socket;

	//typedef CUsersList<CNetUser> CNetUsers;

	//CNetUsers m_userList;
};
