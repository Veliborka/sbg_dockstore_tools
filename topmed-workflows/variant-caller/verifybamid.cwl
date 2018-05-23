class: CommandLineTool
cwlVersion: v1.0
id: vladimir_obucina/topmed-freeze-3a-variant-calling-pipeline/verifybamid_cwl1/6
baseCommand: []
inputs:
  - format: 'BAI,CRAI'
    'sbg:category': Input Files
    id: bai_crai_file
    type: 'File[]'
    label: BAI/CRAI File
    doc: Index file for BAM/CRAM
    'sbg:fileTypes': 'BAI, CRAI'
  - format: 'BAM,CRAM'
    'sbg:category': Input Files
    id: bam_cram_file
    type: File
    label: BAM/CRAM File
    doc: Bam or Cram file for the sample
    'sbg:fileTypes': 'BAM, CRAM'
  - format: FA
    'sbg:category': Input Files
    id: reference
    type: File
    inputBinding:
      position: 1
      shellQuote: false
      valueFrom: |-
        ${

            return ""

        }
    label: Reference
    doc: Reference file
    'sbg:fileTypes': FA
    secondaryFiles:
      - .fai
  - 'sbg:category': Input file
    id: reference_genome
    type:
      type: enum
      symbols:
        - hg19
        - hg38
      name: reference_genome
    label: Reference genome
outputs:
  - id: output_index_file
    doc: Output for topmed freeze3 pipeline
    label: Output Index File
    type: File?
    outputBinding:
      glob: |-
        ${
            return inputs.bam_cram_file.path.split("/").pop().split(".").shift() + ".index"

        }
    format: INDEX
doc: >-
  **VerifyBamID** is a software that verifies whether the reads in particular
  file match previously known genotypes for an individual (or group of
  individuals), and checks whether the reads are contaminated as a mixture of
  two samples. verifyBamID can detect sample contamination and swaps when
  external genotypes are available. When external genotypes are not available,
  verifyBamID still robustly detects sample swaps.
label: VerifyBamID_CWL1
arguments:
  - position: 0
    prefix: ''
    separate: false
    shellQuote: false
    valueFrom: |-
      ${
          if (inputs.reference_genome == 'hg19') {
              var UDPath = "/VerifyBamID/resource/1000g.phase3.100k.b37.vcf.gz.dat.UD"
              var BedPath = "/VerifyBamID/resource/1000g.phase3.100k.b37.vcf.gz.dat.bed"
              var MeanPath = "/VerifyBamID/resource/1000g.phase3.100k.b37.vcf.gz.dat.mu"
          } else if (inputs.reference_genome == 'hg38') {
              var UDPath = "/VerifyBamID/resource/1000g.phase3.100k.b38.vcf.gz.dat.UD"
              var BedPath = "/VerifyBamID/resource/1000g.phase3.100k.b38.vcf.gz.dat.bed"
              var MeanPath = "/VerifyBamID/resource/1000g.phase3.100k.b38.vcf.gz.dat.mu"
          }

          var comm = "export PATH=$PATH:/VerifyBamID/bin/ && VerifyBamID \
       --UDPath " + UDPath + " \
       --BedPath " + BedPath + " \
       --MeanPath " + MeanPath + " \
       --Reference " + inputs.reference.path + " --BamFile " + inputs.bam_cram_file.path
          comm += " && python make_index.py --file "
          comm += inputs.bam_cram_file.path.split("/").pop().split(".").shift()
          comm += " --path " + inputs.bam_cram_file.path + " --result result.out"

          return comm
      }
requirements:
  - class: ShellCommandRequirement
  - class: ResourceRequirement
    ramMin: 1000
    coresMin: 1
  - class: DockerRequirement
    dockerPull: 'images.sbgenomics.com/vladimir_obucina/topmed:VerifyBamID'
  - class: InitialWorkDirRequirement
    listing:
      - entryname: make_index.py
        entry: |-
          import sys
          import glob, os
          import argparse

          parser = argparse.ArgumentParser()


          parser.add_argument("--file", help="File name.", type=str)
          parser.add_argument("--path", help="Path to file.", type=str)
          parser.add_argument("--result", help="Result from ", type=str)

          args = parser.parse_args()

          with open(args.result, 'rt') as in_file:
              contents = in_file.read()
              broj = contents.split("Alpha:",4)
              contamination = broj[1].rstrip()



          output_file = args.file + ".index"
          f = open (output_file, "w+")

          f.write(args.file + '\t' + args.path + '\t' + contamination + '\n')

          f.close()
  - class: InlineJavascriptRequirement
    expressionLib:
      - |-
        var updateMetadata = function(file, key, value) {
            file['metadata'][key] = value;
            return file;
        };


        var setMetadata = function(file, metadata) {
            if (!('metadata' in file))
                file['metadata'] = metadata;
            else {
                for (var key in metadata) {
                    file['metadata'][key] = metadata[key];
                }
            }
            return file
        };

        var inheritMetadata = function(o1, o2) {
            var commonMetadata = {};
            if (!Array.isArray(o2)) {
                o2 = [o2]
            }
            for (var i = 0; i < o2.length; i++) {
                var example = o2[i]['metadata'];
                for (var key in example) {
                    if (i == 0)
                        commonMetadata[key] = example[key];
                    else {
                        if (!(commonMetadata[key] == example[key])) {
                            delete commonMetadata[key]
                        }
                    }
                }
            }
            if (!Array.isArray(o1)) {
                o1 = setMetadata(o1, commonMetadata)
            } else {
                for (var i = 0; i < o1.length; i++) {
                    o1[i] = setMetadata(o1[i], commonMetadata)
                }
            }
            return o1;
        };

        var toArray = function(file) {
            return [].concat(file);
        };

        var groupBy = function(files, key) {
            var groupedFiles = [];
            var tempDict = {};
            for (var i = 0; i < files.length; i++) {
                var value = files[i]['metadata'][key];
                if (value in tempDict)
                    tempDict[value].push(files[i]);
                else tempDict[value] = [files[i]];
            }
            for (var key in tempDict) {
                groupedFiles.push(tempDict[key]);
            }
            return groupedFiles;
        };

        var orderBy = function(files, key, order) {
            var compareFunction = function(a, b) {
                if (a['metadata'][key].constructor === Number) {
                    return a['metadata'][key] - b['metadata'][key];
                } else {
                    var nameA = a['metadata'][key].toUpperCase();
                    var nameB = b['metadata'][key].toUpperCase();
                    if (nameA < nameB) {
                        return -1;
                    }
                    if (nameA > nameB) {
                        return 1;
                    }
                    return 0;
                }
            };

            files = files.sort(compareFunction);
            if (order == undefined || order == "asc")
                return files;
            else
                return files.reverse();
        };
$namespaces:
  sbg: 'https://sevenbridges.com'
'sbg:appVersion':
  - v1.0
'sbg:cmdPreview': >-
  export PATH=$PATH:/VerifyBamID/bin/ && VerifyBamID  --UDPath
  /VerifyBamID/resource/1000g.phase3.100k.b37.vcf.gz.dat.UD  --BedPath
  /VerifyBamID/resource/1000g.phase3.100k.b37.vcf.gz.dat.bed  --MeanPath
  /VerifyBamID/resource/1000g.phase3.100k.b37.vcf.gz.dat.mu  --Reference
  /path/to/reference.ext --BamFile /path/to/bam_file.ext && python make_index.py
  --file bam_file --path /root/topmed_freeze3_calling/bam_file.ext --result
  result.out
'sbg:contributors':
  - vladimir_obucina
'sbg:createdBy': vladimir_obucina
'sbg:createdOn': 1526995337
'sbg:id': vladimir_obucina/topmed-freeze-3a-variant-calling-pipeline/verifybamid_cwl1/6
'sbg:image_url': >-
  https://igor.sbgenomics.com/ns/brood/images/vladimir_obucina/topmed-freeze-3a-variant-calling-pipeline/verifybamid_cwl1/6.png
'sbg:latestRevision': 6
'sbg:modifiedBy': vladimir_obucina
'sbg:modifiedOn': 1527071592
'sbg:project': vladimir_obucina/topmed-freeze-3a-variant-calling-pipeline
'sbg:projectName': TOPMed Freeze 3a Variant Calling Pipeline
'sbg:publisher': sbg
'sbg:revision': 6
'sbg:revisionNotes': 'UPDATE: changed generating index file, \n was missing at the end of file.'
'sbg:revisionsInfo':
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1526995337
    'sbg:revision': 0
    'sbg:revisionNotes': null
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1526995452
    'sbg:revision': 1
    'sbg:revisionNotes': First version
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1526995574
    'sbg:revision': 2
    'sbg:revisionNotes': After conversion there weren't fyle types in the input ports. Added it
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1526996077
    'sbg:revision': 3
    'sbg:revisionNotes': ''
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1527013794
    'sbg:revision': 4
    'sbg:revisionNotes': Removed /topmed_freeze3/   from path in middle column
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1527069678
    'sbg:revision': 5
    'sbg:revisionNotes': ''
  - 'sbg:modifiedBy': vladimir_obucina
    'sbg:modifiedOn': 1527071592
    'sbg:revision': 6
    'sbg:revisionNotes': 'UPDATE: changed generating index file, \n was missing at the end of file.'
'sbg:sbgMaintained': false
'sbg:validationErrors': []