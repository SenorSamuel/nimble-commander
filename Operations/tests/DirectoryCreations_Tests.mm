// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include "../source/DirectoryCreation/DirectoryCreation.h"
#include <boost/filesystem.hpp>
#include "Environment.h"
#include <sys/stat.h>

static const auto g_LocalFTP =  NCE(nc::env::test::ftp_qnap_nas_host);

using namespace nc::ops;
using namespace nc::vfs;

@interface DirectoryCreationTests : XCTestCase
@end


@implementation DirectoryCreationTests
{
    boost::filesystem::path m_TmpDir;
    std::shared_ptr<VFSHost> m_NativeHost;
}

- (void)setUp
{
    [super setUp];
    m_NativeHost = VFSNativeHost::SharedHost();
    m_TmpDir = self.makeTmpDir;
}

- (void)tearDown
{
    VFSEasyDelete(m_TmpDir.c_str(), VFSNativeHost::SharedHost());
    [super tearDown];
}

- (void)testSimpleCreation
{
    DirectoryCreation operation{ "Test", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists((m_TmpDir/"Test").c_str()) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test").c_str(), 0) );
}

- (void)testMultipleDirectoriesCreation
{
    DirectoryCreation operation{ "Test1/Test2/Test3", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2/Test3").c_str(), 0) );
}

- (void)testTrailingSlashes
{
    DirectoryCreation operation{ "Test///", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test").c_str(), 0) );
}

- (void)testHeadingSlashes
{
    DirectoryCreation operation{ "///Test", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test").c_str(), 0) );
}

- (void)testEmptyInput
{
    DirectoryCreation operation{ "", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
}

- (void)testWeirdInput
{
    DirectoryCreation operation{ "!@#$%^&*()_+", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"!@#$%^&*()_+").c_str(), 0) );
}

- (void)testAlredyExistingDir
{
    mkdir( (m_TmpDir/"Test1").c_str(), 0755 );
    DirectoryCreation operation{ "Test1/Test2/Test3", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2/Test3").c_str(), 0) );
}

- (void)testAlredyExistingRegFile
{
    close( creat( (m_TmpDir/"Test1").c_str(), 0755 ) );
    DirectoryCreation operation{ "Test1/Test2/Test3", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() != OperationState::Completed );
    XCTAssert( m_NativeHost->Exists((m_TmpDir/"Test1").c_str()) );
    XCTAssert( !m_NativeHost->IsDirectory((m_TmpDir/"Test1").c_str(), 0) );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"Test1/Test2").c_str()) );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"Test1/Test2/Test3").c_str()) );
}

- (void)testOnLocalFTPServer
{
    VFSHostPtr host;
    try {
        host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    {
        DirectoryCreation operation("/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/",
                                "/",
                                *host);
        operation.Start();
        operation.Wait();
    }
    
    VFSStat st;
    XCTAssert( host->Stat("/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/", st, 0, 0) == 0);
    XCTAssert( VFSEasyDelete("/Public/!FilesTesting/Dir", host) == 0);
    
    {
        DirectoryCreation operation("AnotherDir/AndSecondOne",
                                    "/Public/!FilesTesting",
                                    *host);
        operation.Start();
        operation.Wait();
    }
    
    XCTAssert( host->Stat("/Public/!FilesTesting/AnotherDir/AndSecondOne", st, 0, 0) == 0);
    XCTAssert( VFSEasyDelete("/Public/!FilesTesting/AnotherDir", host) == 0);
}


- (boost::filesystem::path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir,
            "%s" "com.magnumbytes.nimblecommander" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end
