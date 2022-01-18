# oncopubs

_oncopubs_ is the input repository to register publications for the progenetix collection.

Monitored technologies include:

* "cCGH" - Chromosomal based Comparative Genomic Hybridization (CGH)
* "aCGH" - genomic arrays, referring to two color CGH arrays as well as other genomic arrays suitable for reconstructing copy number aberration data (SNP arrays ...)
* "WES" - whole exome sequencing
* "WGS" - whole genome sequencing

The data is represented through the [publications portal](http://progenetix.org/publications/) of the Progenetix website.

To contribute to the extension of this repository minimal data is required. PMID, number of samples and information about the technology used should be provided - please use the template file for submissions into the [`incoming`](./incoming/) directory.

All contributions will be reviewed by our group and then they will be included in our database.

## Publication template file

The template file is provided as a tab-delimited data table. It can be opened in
text editors or spreadheet software, but please make sure to save the edited file
then again as tab-delimited file.

The order of the columns can be changed, but please do not modify the header values.

### Data Columns

#### `#`

Any value here (but use `#`) skips this line during import (e.g. for example data,
  testing, keeping processed entries...).

#### `pubmedid`

The PMID, and only this.

#### `counts.ccgh`

Number of chromosomal CGH experiments in the publication.

#### `counts.acgh`

Number of genomic array experiments (full genome only, not focal!) in the publication.

#### `counts.wes`

Number of whole exome sequencing experiments in the publication.

#### `counts.wgs`

Number of whole exome sequencing experiments in the publication.

#### `counts.genomes`

Number of genomes analyzed in th estudy; this may be less than the sum from different
technologies - e.g. a study using 100 arrays may include 10 WGS experiments of some
of the samples, keeping the genomes count at 100.

#### `contact.name`

Name of (one of) the corresponding author(s). Optional.

#### `contact.email`

email of (one of) the corresponding author(s). Optional.

#### `contact.affiliation`

Institution of (one of) the corresponding author(s). Optional.

#### `#provenance_id`

The geo key used to identify the city of origin. This can be looked up using the
[bycon services API](https://info.progenetix.org/doc/services/geolocations.html):

* use the URL `https://progenetix.org/services/geolocations?city=` with an added city / start of city name (e.g. `New`)
  - <https://progenetix.org/services/geolocations?city=New>
* scroll the response for the correct location & copy the `id` value
  - e.g. `newcastleupontyne::unitedkingdom`

#### `status`

The status is mostly for internal use, e.g. labeling publications as `excluded [GWAS study]` or such.
One direct use case is the collection of articles which may not have original data
but use the Progenetix resource (`excluded [Progenetix use]`).

#### `#sample_types`

This field is for adding information about the _approximate_ diagnoses of the analyzed
cancer samples using the NCIt neoplasm codes. The codes themselves can be [found
on the Progenetix website](https://progenetix.org/subsets/biosubsets/?filters=NCIT).

The format is `__NCIT code__::__label__::__count__`. If several tumor diagnoses are
included one can use several of those "blocks" and concatenate them with a `semicolon`.

**Example** `NCIT:C4917::Lung Small Cell Carcinoma::36;NCIT:C2926::Lung Non-Small Cell Carcinoma::86`

If this is left empty we will try to update later.

#### `note`

For some comments - can be empty ...

#### `progenetix_use`

This is a special field to labe publications which have used or cited the Progenetix
ecosystem to [list them on a dedicated page](https://progenetix.org/publications/progenetixuse/).

The field should be left empty - or labeled `yes` in case of Progenetix use.

#### `progenetix_curator`

Name of the person providing the entry.

## Progenetix `publications` update procedure (locally...)

To insert/update the Progenetix publications database one uses the `publicationsInserter.py` script from the [`byconeer` package](http://github.com/progenetix/byconeer/) and points it to the local version of an updated publication table. The script will fetch the extended information for the PMIDs (authors, title, abstract ...), combine those with the table annotations and create database entries (which become immediately available online if run on the Progenetix server).

Example:

```
./publicationsInserter.py -i ~/Github/oncopubs/incoming/2022-01-13-genome-screening-articles.tsv
```

#### Options:

* `-u 1` overwrites existing records with the same PMIDs, e.g. after adding/correcting annotations
* `-t 1` activates a test mode (JSON of data is shown but not inserted)
