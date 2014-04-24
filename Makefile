TOP := $(shell pwd)
RESGEN=resgen
BOOTSTRAP_MCS=mcs
BOOTSTRAP_DIR=$(TOP)/bootstrap
CSC=mono $(BOOTSTRAP_DIR)/rcsc.exe
OUTPUT_DIR=$(TOP)/rcsc
#MONO_DIR=/opt/mono
MONO_DIR=/Library/Frameworks/Mono.framework/Versions/Current
FACADES_DIR=$(MONO_DIR)/lib/mono/4.5/Facades
MSBUILD_DIR=$(MONO_DIR)/lib/mono/gac/Microsoft.Build.Tasks.v12.0/12.0.0.0__b03f5f7f11d50a3a
IMMUTABLE_LIB=packages/Microsoft.Bcl.Immutable.1.1.20-beta/lib/portable-net45+win8/System.Collections.Immutable.dll
METADATA_LIB=packages/Microsoft.Bcl.Metadata.1.0.9-alpha/lib/portable-net45+win8/System.Reflection.Metadata.dll

.PHONY: rcsc

resources:
	cd Src/Compilers/Core/Source/ && $(RESGEN) CodeAnalysisResources.resx Microsoft.CodeAnalysis.CodeAnalysisResources.resources
	cd Src/Compilers/CSharp/Source/ && $(RESGEN) CSharpResources.resx Microsoft.CodeAnalysis.CSharp.CSharpResources.resources

packages:
	mono Src/.nuget/NuGet.exe restore Src/Roslyn.sln

bootstrap: resources packages
	mkdir -p $(BOOTSTRAP_DIR)
	cd Src/Tools/Source/CompilerGeneratorTools/Source/BoundTreeGenerator && $(BOOTSTRAP_MCS) -out:$(BOOTSTRAP_DIR)/BoundTreeGenerator.exe BoundNodeClassWriter.cs \
	Model.cs Program.cs
	cd Src/Compilers/CSharp/Source/BoundTree && mono $(BOOTSTRAP_DIR)/BoundTreeGenerator.exe CSharp BoundNodes.xml BoundNodes.xml.Generated.cs
	cd Src/Tools/Source/CompilerGeneratorTools/Source/CSharpErrorFactsGenerator && $(BOOTSTRAP_MCS) -out:$(BOOTSTRAP_DIR)/CSharpErrorFactsGenerator.exe Program.cs
	cd Src/Compilers/CSharp/Source/Errors && mono $(BOOTSTRAP_DIR)/CSharpErrorFactsGenerator.exe ErrorCode.cs ErrorFacts.Generated.cs
	cd Src/Tools/Source/CompilerGeneratorTools/Source/CSharpSyntaxGenerator && $(BOOTSTRAP_MCS) -out:$(BOOTSTRAP_DIR)/CSharpSyntaxGenerator.exe *.cs
	cd Src/Compilers/CSharp/Source/Syntax && mono $(BOOTSTRAP_DIR)/CSharpSyntaxGenerator.exe Syntax.xml Syntax.xml.Generated.cs
	cd Src/Compilers/Core/Source/ && $(BOOTSTRAP_MCS) -t:library -out:$(BOOTSTRAP_DIR)/Microsoft.CodeAnalysis.dll -unsafe -d:BOOTSTRAP -d:COMPILERCORE -noconfig \
		-r:$(FACADES_DIR)/System.Runtime.dll -r:../../../$(IMMUTABLE_LIB) \
		-r:../../../$(METADATA_LIB) -r:$(FACADES_DIR)/System.Collections.dll  @files.lst \
		-r:System.Core -r:System -r:System.Xml -r:System.Xml.Linq -r:$(FACADES_DIR)/System.Reflection.Primitives.dll \
		-r:$(FACADES_DIR)/System.IO.dll -resource:Microsoft.CodeAnalysis.CodeAnalysisResources.resources
	cd Src/Compilers/CSharp/Source/ && $(BOOTSTRAP_MCS) -t:library -out:$(BOOTSTRAP_DIR)/Microsoft.CodeAnalysis.CSharp.dll -unsafe -d:BOOTSTRAP -noconfig \
		-r:$(FACADES_DIR)/System.Runtime.dll -r:../../../$(IMMUTABLE_LIB) \
		-r:../../../$(METADATA_LIB) -r:$(BOOTSTRAP_DIR)/Microsoft.CodeAnalysis.dll @files.lst \
		-r:System.Core -r:System -r:System.Xml -r:System.Xml.Linq -resource:Microsoft.CodeAnalysis.CSharp.CSharpResources.resources
	cd Src/Compilers/CSharp/rcsc/ && $(BOOTSTRAP_MCS) -out:$(BOOTSTRAP_DIR)/rcsc.exe Csc.cs Program.cs \
		-r:$(BOOTSTRAP_DIR)/Microsoft.CodeAnalysis.dll -r:$(BOOTSTRAP_DIR)/Microsoft.CodeAnalysis.CSharp.dll \
		-r:../../../$(IMMUTABLE_LIB) -r:$(FACADES_DIR)/System.Runtime.dll
	cp Src/$(IMMUTABLE_LIB) $(BOOTSTRAP_DIR)
	cp Src/$(METADATA_LIB) $(BOOTSTRAP_DIR)

rcsc: $(OUTPUT_DIR)/rcsc.exe

$(OUTPUT_DIR)/rcsc.exe: $(BOOTSTRAP_DIR)/rcsc.exe
	mkdir -p $(OUTPUT_DIR)
	cd Src/Compilers/Core/Source/ && $(CSC) -t:library -out:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.dll -unsafe -d:COMPILERCORE -noconfig -parallel- \
		-r:$(FACADES_DIR)/System.Runtime.dll -r:../../../$(IMMUTABLE_LIB) \
		-r:../../../$(METADATA_LIB) -r:$(FACADES_DIR)/System.Collections.dll  @files.lst \
		-r:System.Core.dll -r:System.dll -r:System.Xml.dll -r:System.Xml.Linq.dll -r:$(FACADES_DIR)/System.Reflection.Primitives.dll \
		-r:$(FACADES_DIR)/System.IO.dll -resource:Microsoft.CodeAnalysis.CodeAnalysisResources.resources
	cd Src/Compilers/CSharp/Source/ && $(CSC) -t:library -out:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.CSharp.dll -unsafe -noconfig \
		-r:$(FACADES_DIR)/System.Runtime.dll -r:../../../$(IMMUTABLE_LIB) \
		-r:../../../$(METADATA_LIB) -r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.dll @files.lst \
		-r:System.Core.dll -r:System.dll -r:System.Xml.dll -r:System.Xml.Linq.dll -resource:Microsoft.CodeAnalysis.CSharp.CSharpResources.resources
	cd Src/Compilers/CSharp/rcsc/ && $(CSC) -out:$(OUTPUT_DIR)/rcsc.exe Csc.cs Program.cs \
		-r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.dll -r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.CSharp.dll \
		-r:../../../$(IMMUTABLE_LIB) -r:$(FACADES_DIR)/System.Runtime.dll \
		-r:System.Core.dll
	cp Src/$(IMMUTABLE_LIB) $(OUTPUT_DIR)
	cp Src/$(METADATA_LIB) $(OUTPUT_DIR)
	cp Src/Compilers/CSharp/rcsc/*.rsp $(OUTPUT_DIR)

use-roslyn:
	sed "s,/Library/Frameworks/Mono.framework/Versions/[0-9\.]*/lib/mono/4.5/mcs.exe,`pwd`/rcsc/rcsc.exe," < /usr/bin/mcs > tmp
	sed "s,/Library/Frameworks/Mono.framework/Versions/[0-9\.]*/lib/mono/4.5/mcs.exe,`pwd`/rcsc/rcsc.exe," < /Library/Frameworks/Mono.framework/Versions/Current/bin/mcs > tmp2
	chmod +x tmp tmp2
	sudo sh -c "(cp tmp2 /Library/Frameworks/Mono.framework/Versions/Current/bin/mcs; sudo cp tmp /usr/bin/mcs)"


undo:
	sudo sh -c "(cp /Library/Frameworks/Mono.framework/Versions/Current/bin/backup-mcs /Library/Frameworks/Mono.framework/Versions/Current/bin/mcs; cp /usr/bin/mcs-backup /usr/bin/mcs)"

workspace:
	cd Src/Workspaces/Core/ && $(RESGEN) WorkspacesResources.resx Microsoft.CodeAnalysis.Workspaces.WorkspacesResources.resources	
	cd Src/Workspaces/Core/ && $(CSC) -t:library -out:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.Workspaces.dll -unsafe -d:MEF -noconfig @files.lst \
	-r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.dll -r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.CSharp.dll \
	-r:$(FACADES_DIR)/System.Runtime.dll -r:$(FACADES_DIR)/System.Collections.dll \
	-r:System.Core.dll -r:System.dll -r:System.Xml.dll -r:System.Xml.Linq.dll -r:Microsoft.Build.dll -r:Microsoft.Build.Framework.dll \
	-r:../../$(IMMUTABLE_LIB) -r:System.ComponentModel.Composition.dll \
	-resource:Microsoft.CodeAnalysis.Workspaces.WorkspacesResources.resources

csharp-workspace:
	cd Src/Workspaces/CSharp/ && $(RESGEN) CSharpWorkspaceResources.resx Microsoft.CodeAnalysis.CSharp.Workspaces.CSharpWorkspaceResources.resources		
	cd Src/Workspaces/CSharp/ && $(CSC) -t:library -out:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.CSharp.Workspaces.dll -d:MEF -noconfig @files.lst \
	-r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.dll -r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.CSharp.dll -r:$(OUTPUT_DIR)/Microsoft.CodeAnalysis.Workspaces.dll \
	-r:$(FACADES_DIR)/System.Runtime.dll -r:$(FACADES_DIR)/System.Collections.dll \
	-r:System.Core.dll -r:System.dll -r:System.Xml.dll -r:System.Xml.Linq.dll -r:Microsoft.Build.dll -r:Microsoft.Build.Framework.dll \
	-r:../../$(IMMUTABLE_LIB) -r:System.ComponentModel.Composition.dll \
	-r:$(MSBUILD_DIR)/Microsoft.Build.Tasks.v12.0.dll \
	-resource:Microsoft.CodeAnalysis.CSharp.Workspaces.CSharpWorkspaceResources.resources
