##
## Auto Generated makefile by CodeLite IDE
## any manual changes will be erased      
##
## Debug
ProjectName            :=LuaNode
ConfigurationName      :=Debug
IntermediateDirectory  :=./Debug
OutDir                 := $(IntermediateDirectory)
WorkspacePath          := "D:\trunk_git\sources\LuaNode\build\codelite"
ProjectPath            := "D:\trunk_git\sources\LuaNode\build\codelite"
CurrentFileName        :=
CurrentFilePath        :=
CurrentFileFullPath    :=
User                   :=Ignacio
Date                   :=09/03/10
CodeLitePath           :="C:\Program Files (x86)\CodeLite"
LinkerName             :=g++
ArchiveTool            :=ar rcus
SharedObjectLinkerName :=g++ -shared -fPIC
ObjectSuffix           :=.o
DependSuffix           :=.o.d
PreprocessSuffix       :=.o.i
DebugSwitch            :=-gstab
IncludeSwitch          :=-I
LibrarySwitch          :=-l
OutputSwitch           :=-o 
LibraryPathSwitch      :=-L
PreprocessorSwitch     :=-D
SourceSwitch           :=-c 
CompilerName           :=g++
C_CompilerName         :=gcc
OutputFile             :=$(IntermediateDirectory)/$(ProjectName)
Preprocessors          :=$(PreprocessorSwitch)_WIN32_WINNT=0x0501 
ObjectSwitch           :=-o 
ArchiveOutputSwitch    := 
PreprocessOnlySwitch   :=-E 
MakeDirCommand         :=makedir
CmpOptions             := -g $(Preprocessors)
LinkOptions            :=  
IncludePath            :=  "$(IncludeSwitch)." "$(IncludeSwitch)." "$(IncludeSwitch)$(INCONCERT_DEVEL)/sources" "$(IncludeSwitch)$(INCONCERT_DEVEL)/packages/boost_1_44_0" 
RcIncludePath          :=
Libs                   :=$(LibrarySwitch)Lua5.1 $(LibrarySwitch)supportlib $(LibrarySwitch)blogger2 $(LibrarySwitch)WS2_32 
LibPath                := "$(LibraryPathSwitch)." "$(LibraryPathSwitch)d:/trunk_git/lib" "$(LibraryPathSwitch)$(INCONCERT_DEVEL)/lib" "$(LibraryPathSwitch)$(INCONCERT_DEVEL)/packages/Lua5.1/lib" "$(LibraryPathSwitch)$(INCONCERT_DEVEL)/packages/boost_1_44_0/lib" 


##
## User defined environment variables
##
CodeLiteDir:=C:\Program Files (x86)\CodeLite
UNIT_TEST_PP_SRC_DIR:=C:\UnitTest++-1.3
WXWIN:=C:\wxWidgets-2.8.10
PATH:=$(WXWIN)\lib\gcc_dll;$(PATH)
WXCFG:=gcc_dll\mswu
Objects=$(IntermediateDirectory)/src_blogger$(ObjectSuffix) $(IntermediateDirectory)/src_EvaluadorLUA$(ObjectSuffix) $(IntermediateDirectory)/src_LuaNode$(ObjectSuffix) $(IntermediateDirectory)/src_LuaRuntime$(ObjectSuffix) $(IntermediateDirectory)/src_stdafx$(ObjectSuffix) $(IntermediateDirectory)/Network_NamedIndex$(ObjectSuffix) $(IntermediateDirectory)/Network_Socket$(ObjectSuffix) $(IntermediateDirectory)/Network_SocketAllocator$(ObjectSuffix) $(IntermediateDirectory)/Network_StreamSocketServer$(ObjectSuffix) $(IntermediateDirectory)/src_ClientConnection$(ObjectSuffix) \
	$(IntermediateDirectory)/src_SocketServer$(ObjectSuffix) 

##
## Main Build Targets 
##
all: $(OutputFile)

$(OutputFile): makeDirStep $(Objects)
	@$(MakeDirCommand) $(@D)
	$(LinkerName) $(OutputSwitch)$(OutputFile) $(Objects) $(LibPath) $(Libs) $(LinkOptions)

makeDirStep:
	@$(MakeDirCommand) "./Debug"

PreBuild:


##
## Objects
##
$(IntermediateDirectory)/src_blogger$(ObjectSuffix): ../../src/blogger.cpp $(IntermediateDirectory)/src_blogger$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/blogger.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_blogger$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_blogger$(DependSuffix): ../../src/blogger.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_blogger$(ObjectSuffix) -MF$(IntermediateDirectory)/src_blogger$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/blogger.cpp"

$(IntermediateDirectory)/src_blogger$(PreprocessSuffix): ../../src/blogger.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_blogger$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/blogger.cpp"

$(IntermediateDirectory)/src_EvaluadorLUA$(ObjectSuffix): ../../src/EvaluadorLUA.cpp $(IntermediateDirectory)/src_EvaluadorLUA$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/EvaluadorLUA.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_EvaluadorLUA$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_EvaluadorLUA$(DependSuffix): ../../src/EvaluadorLUA.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_EvaluadorLUA$(ObjectSuffix) -MF$(IntermediateDirectory)/src_EvaluadorLUA$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/EvaluadorLUA.cpp"

$(IntermediateDirectory)/src_EvaluadorLUA$(PreprocessSuffix): ../../src/EvaluadorLUA.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_EvaluadorLUA$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/EvaluadorLUA.cpp"

$(IntermediateDirectory)/src_LuaNode$(ObjectSuffix): ../../src/LuaNode.cpp $(IntermediateDirectory)/src_LuaNode$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/LuaNode.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_LuaNode$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_LuaNode$(DependSuffix): ../../src/LuaNode.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_LuaNode$(ObjectSuffix) -MF$(IntermediateDirectory)/src_LuaNode$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/LuaNode.cpp"

$(IntermediateDirectory)/src_LuaNode$(PreprocessSuffix): ../../src/LuaNode.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_LuaNode$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/LuaNode.cpp"

$(IntermediateDirectory)/src_LuaRuntime$(ObjectSuffix): ../../src/LuaRuntime.cpp $(IntermediateDirectory)/src_LuaRuntime$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/LuaRuntime.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_LuaRuntime$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_LuaRuntime$(DependSuffix): ../../src/LuaRuntime.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_LuaRuntime$(ObjectSuffix) -MF$(IntermediateDirectory)/src_LuaRuntime$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/LuaRuntime.cpp"

$(IntermediateDirectory)/src_LuaRuntime$(PreprocessSuffix): ../../src/LuaRuntime.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_LuaRuntime$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/LuaRuntime.cpp"

$(IntermediateDirectory)/src_stdafx$(ObjectSuffix): ../../src/stdafx.cpp $(IntermediateDirectory)/src_stdafx$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/stdafx.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_stdafx$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_stdafx$(DependSuffix): ../../src/stdafx.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_stdafx$(ObjectSuffix) -MF$(IntermediateDirectory)/src_stdafx$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/stdafx.cpp"

$(IntermediateDirectory)/src_stdafx$(PreprocessSuffix): ../../src/stdafx.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_stdafx$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/stdafx.cpp"

$(IntermediateDirectory)/Network_NamedIndex$(ObjectSuffix): ../../src/Network/NamedIndex.cpp $(IntermediateDirectory)/Network_NamedIndex$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/Network/NamedIndex.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/Network_NamedIndex$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/Network_NamedIndex$(DependSuffix): ../../src/Network/NamedIndex.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/Network_NamedIndex$(ObjectSuffix) -MF$(IntermediateDirectory)/Network_NamedIndex$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/Network/NamedIndex.cpp"

$(IntermediateDirectory)/Network_NamedIndex$(PreprocessSuffix): ../../src/Network/NamedIndex.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/Network_NamedIndex$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/Network/NamedIndex.cpp"

$(IntermediateDirectory)/Network_Socket$(ObjectSuffix): ../../src/Network/Socket.cpp $(IntermediateDirectory)/Network_Socket$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/Network/Socket.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/Network_Socket$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/Network_Socket$(DependSuffix): ../../src/Network/Socket.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/Network_Socket$(ObjectSuffix) -MF$(IntermediateDirectory)/Network_Socket$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/Network/Socket.cpp"

$(IntermediateDirectory)/Network_Socket$(PreprocessSuffix): ../../src/Network/Socket.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/Network_Socket$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/Network/Socket.cpp"

$(IntermediateDirectory)/Network_SocketAllocator$(ObjectSuffix): ../../src/Network/SocketAllocator.cpp $(IntermediateDirectory)/Network_SocketAllocator$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/Network/SocketAllocator.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/Network_SocketAllocator$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/Network_SocketAllocator$(DependSuffix): ../../src/Network/SocketAllocator.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/Network_SocketAllocator$(ObjectSuffix) -MF$(IntermediateDirectory)/Network_SocketAllocator$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/Network/SocketAllocator.cpp"

$(IntermediateDirectory)/Network_SocketAllocator$(PreprocessSuffix): ../../src/Network/SocketAllocator.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/Network_SocketAllocator$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/Network/SocketAllocator.cpp"

$(IntermediateDirectory)/Network_StreamSocketServer$(ObjectSuffix): ../../src/Network/StreamSocketServer.cpp $(IntermediateDirectory)/Network_StreamSocketServer$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/Network/StreamSocketServer.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/Network_StreamSocketServer$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/Network_StreamSocketServer$(DependSuffix): ../../src/Network/StreamSocketServer.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/Network_StreamSocketServer$(ObjectSuffix) -MF$(IntermediateDirectory)/Network_StreamSocketServer$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/Network/StreamSocketServer.cpp"

$(IntermediateDirectory)/Network_StreamSocketServer$(PreprocessSuffix): ../../src/Network/StreamSocketServer.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/Network_StreamSocketServer$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/Network/StreamSocketServer.cpp"

$(IntermediateDirectory)/src_ClientConnection$(ObjectSuffix): ../../src/ClientConnection.cpp $(IntermediateDirectory)/src_ClientConnection$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/ClientConnection.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_ClientConnection$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_ClientConnection$(DependSuffix): ../../src/ClientConnection.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_ClientConnection$(ObjectSuffix) -MF$(IntermediateDirectory)/src_ClientConnection$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/ClientConnection.cpp"

$(IntermediateDirectory)/src_ClientConnection$(PreprocessSuffix): ../../src/ClientConnection.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_ClientConnection$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/ClientConnection.cpp"

$(IntermediateDirectory)/src_SocketServer$(ObjectSuffix): ../../src/SocketServer.cpp $(IntermediateDirectory)/src_SocketServer$(DependSuffix)
	$(CompilerName) $(SourceSwitch) "D:/trunk_git/sources/LuaNode/src/SocketServer.cpp" $(CmpOptions) $(ObjectSwitch)$(IntermediateDirectory)/src_SocketServer$(ObjectSuffix) $(IncludePath)
$(IntermediateDirectory)/src_SocketServer$(DependSuffix): ../../src/SocketServer.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) -MT$(IntermediateDirectory)/src_SocketServer$(ObjectSuffix) -MF$(IntermediateDirectory)/src_SocketServer$(DependSuffix) -MM "D:/trunk_git/sources/LuaNode/src/SocketServer.cpp"

$(IntermediateDirectory)/src_SocketServer$(PreprocessSuffix): ../../src/SocketServer.cpp
	@$(CompilerName) $(CmpOptions) $(IncludePath) $(PreprocessOnlySwitch) $(OutputSwitch) $(IntermediateDirectory)/src_SocketServer$(PreprocessSuffix) "D:/trunk_git/sources/LuaNode/src/SocketServer.cpp"


-include $(IntermediateDirectory)/*$(DependSuffix)
##
## Clean
##
clean:
	$(RM) $(IntermediateDirectory)/src_blogger$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_blogger$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_blogger$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/src_EvaluadorLUA$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_EvaluadorLUA$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_EvaluadorLUA$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/src_LuaNode$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_LuaNode$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_LuaNode$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/src_LuaRuntime$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_LuaRuntime$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_LuaRuntime$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/src_stdafx$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_stdafx$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_stdafx$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/Network_NamedIndex$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/Network_NamedIndex$(DependSuffix)
	$(RM) $(IntermediateDirectory)/Network_NamedIndex$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/Network_Socket$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/Network_Socket$(DependSuffix)
	$(RM) $(IntermediateDirectory)/Network_Socket$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/Network_SocketAllocator$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/Network_SocketAllocator$(DependSuffix)
	$(RM) $(IntermediateDirectory)/Network_SocketAllocator$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/Network_StreamSocketServer$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/Network_StreamSocketServer$(DependSuffix)
	$(RM) $(IntermediateDirectory)/Network_StreamSocketServer$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/src_ClientConnection$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_ClientConnection$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_ClientConnection$(PreprocessSuffix)
	$(RM) $(IntermediateDirectory)/src_SocketServer$(ObjectSuffix)
	$(RM) $(IntermediateDirectory)/src_SocketServer$(DependSuffix)
	$(RM) $(IntermediateDirectory)/src_SocketServer$(PreprocessSuffix)
	$(RM) $(OutputFile)
	$(RM) $(OutputFile).exe


