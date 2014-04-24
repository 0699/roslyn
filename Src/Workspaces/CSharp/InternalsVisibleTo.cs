// Copyright (c) Microsoft Open Technologies, Inc.  All Rights Reserved.  Licensed under the Apache License, Version 2.0.  See License.txt in the project root for license information.

// WARNING: this file is only to used for adding InternalsVisibleTo attributes to
// binaries that live outside the Roslyn build system. If you want to add an
// InternalsVisibleTo from one assembly to another within Roslyn, update the 
// .csproj file or you will break somebody's build.

using System.Runtime.CompilerServices;

[assembly: InternalsVisibleTo("ICSharpCode.NRefactory6.CSharp")]

